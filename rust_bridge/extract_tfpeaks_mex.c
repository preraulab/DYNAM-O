/*
 * extract_tfpeaks_mex.cpp  —  MATLAB bridge to dynamo_rs::dynamo_extract_tfpeaks
 *
 * Signature from MATLAB (all shapes):
 *     stats = extract_tfpeaks_mex(spect, stimes, sfreqs, baseline, params_struct)
 *
 *     spect:    F x T double (MATLAB column-major)
 *     stimes:   1 x T double
 *     sfreqs:   F x 1 double
 *     baseline: F x 1 double  OR  []  (empty = no baseline division)
 *     params_struct fields (double unless noted):
 *       seg_time, downsample_f (uint32), downsample_t (uint32),
 *       merge_thresh, trim_vol, dur_min, dur_max, bw_min, bw_max,
 *       freq_min, freq_max, ht_db_min
 *
 *     stats: MATLAB struct with fields
 *       PeakTime (Nx1), PeakFrequency (Nx1), Duration (Nx1), Bandwidth (Nx1),
 *       Height (Nx1), Volume (Nx1), SegmentNum (Nx1), BoundingBox (Nx4).
 *     The caller converts to a table via struct2table() if desired.
 *
 * Layout note: the Rust C ABI expects row-major (F, T) spectrogram with
 * spect[f*T + t]. MATLAB stores (F, T) column-major as spect[t*F + f].
 * We transpose via mexCallMATLAB("transpose") before passing: the transposed
 * column-major bytes of (T, F) are identical to row-major bytes of (F, T).
 *
 * Memory: Rust allocates each output array via Box::leak. We copy into
 * mxArrays, then call dynamo_free_buffer_f64 on each Rust pointer.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <math.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

/*
 * Progress reporting is architected to avoid the mexPrintf-from-worker
 * trap: mex*() calls are only safe on the main MATLAB thread. Previously
 * we called mexPrintf directly from Rust's rayon worker callback, which
 * crashed MATLAB (management.cpp:793 "no active context" assertion) on
 * the first 10% tick.
 *
 * Current design:
 *   1. dynamo_extract_tfpeaks runs on a background pthread.
 *   2. Rust workers fire progress_callback as segments complete;
 *      the callback only does atomic_store on shared counters.
 *   3. The main MATLAB thread (inside mexFunction) polls those counters
 *      in a short sleep loop, calling mexPrintf on 10%-boundary crossings
 *      from the main thread — which is safe.
 *   4. When the background thread signals completion, main thread joins
 *      it and proceeds to build the output struct.
 */
static _Atomic uint32_t g_done   = 0;  /* segments completed so far */
static _Atomic uint32_t g_total  = 0;  /* total segments in this call */
static _Atomic bool     g_active = false;

static void progress_callback(uint32_t done, uint32_t total) {
    /* Called from rayon worker threads. MUST NOT invoke any mex*() API.
     * Atomic store is thread-safe and wait-free. */
    atomic_store_explicit(&g_total, total, memory_order_relaxed);
    atomic_store_explicit(&g_done,  done,  memory_order_relaxed);
}

typedef struct {
    const ExtractTfpeaksIn *in;
    ExtractTfpeaksOut *out;
    int rc;
} ExtractThreadArgs;

static void *extract_thread_main(void *vp) {
    ExtractThreadArgs *a = (ExtractThreadArgs *)vp;
    a->rc = dynamo_extract_tfpeaks(a->in, a->out);
    atomic_store_explicit(&g_active, false, memory_order_release);
    return NULL;
}

static double get_double_field(const mxArray *s, const char *name, double def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL) return def;
    if (!mxIsDouble(f) || mxIsComplex(f) || mxGetNumberOfElements(f) == 0) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:badField",
                          "params.%s must be a non-empty real double scalar.", name);
    }
    return mxGetScalar(f);
}

static uint32_t get_u32_field(const mxArray *s, const char *name, uint32_t def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL) return def;
    if (mxGetNumberOfElements(f) == 0) return def;
    return (uint32_t)mxGetScalar(f);
}

static bool get_bool_field(const mxArray *s, const char *name, bool def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL) return def;
    if (mxGetNumberOfElements(f) == 0) return def;
    if (mxIsLogicalScalar(f)) return mxIsLogicalScalarTrue(f);
    return mxGetScalar(f) != 0.0;
}

/* Copy a Rust-allocated double buffer of length n into a new (n, 1) mxArray,
 * then free the Rust buffer. Returns the mxArray (to be stored in plhs
 * fields). Handles n == 0 gracefully (returns empty column). */
static mxArray *take_rust_f64(double *ptr, size_t n) {
    mxArray *out = mxCreateDoubleMatrix((mwSize)n, 1, mxREAL);
    if (n > 0 && ptr != NULL) {
        memcpy(mxGetPr(out), ptr, n * sizeof(double));
        dynamo_free_buffer_f64(ptr, n);
    }
    return out;
}

/* Copy a Rust-allocated N*4 double buffer into an (N, 4) mxArray (MATLAB
 * column-major). Rust stores row-major [t_tl, f_tl, width_s, height_Hz] per
 * peak, so we transpose on the fly. */
static mxArray *take_rust_bbox(double *ptr, size_t n_peaks) {
    mxArray *out = mxCreateDoubleMatrix((mwSize)n_peaks, 4, mxREAL);
    if (n_peaks > 0 && ptr != NULL) {
        double *dst = mxGetPr(out);
        for (size_t i = 0; i < n_peaks; ++i) {
            for (size_t j = 0; j < 4; ++j) {
                dst[j * n_peaks + i] = ptr[i * 4 + j];
            }
        }
        dynamo_free_buffer_f64(ptr, n_peaks * 4);
    }
    return out;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 5) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:nrhs",
            "5 inputs required: spect, stimes, sfreqs, baseline, params");
    }
    if (nlhs > 2) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:nlhs",
            "At most two outputs (stats struct, labels F x T int64).");
    }
    for (int i = 0; i < 4; ++i) {
        if (!mxIsDouble(prhs[i]) || mxIsComplex(prhs[i])) {
            mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:badInput",
                "Input %d must be real double.", i + 1);
        }
    }
    if (!mxIsStruct(prhs[4])) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:badInput",
            "Input 5 (params) must be a struct.");
    }

    mwSize F = mxGetM(prhs[0]);
    mwSize T = mxGetN(prhs[0]);
    if (mxGetNumberOfElements(prhs[1]) != T) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:dims",
            "stimes length (%d) must equal spect columns (%d).",
            (int)mxGetNumberOfElements(prhs[1]), (int)T);
    }
    if (mxGetNumberOfElements(prhs[2]) != F) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:dims",
            "sfreqs length (%d) must equal spect rows (%d).",
            (int)mxGetNumberOfElements(prhs[2]), (int)F);
    }

    /* Transpose spect to row-major. Transposed mxArray's column-major bytes
     * equal the row-major bytes of the original shape. */
    mxArray *spect_t = NULL;
    if (mexCallMATLAB(1, &spect_t, 1, (mxArray **)&prhs[0], "transpose") != 0) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:transpose",
            "Failed to transpose spect.");
    }

    bool has_baseline = mxGetNumberOfElements(prhs[3]) != 0;
    if (has_baseline && mxGetNumberOfElements(prhs[3]) != F) {
        mxDestroyArray(spect_t);
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:dims",
            "baseline length (%d) must equal F (%d) or be empty.",
            (int)mxGetNumberOfElements(prhs[3]), (int)F);
    }

    const mxArray *params = prhs[4];
    ExtractTfpeaksIn in; memset(&in, 0, sizeof(in));
    in.spect_ptr    = mxGetPr(spect_t);
    in.n_freqs      = (size_t)F;
    in.n_times      = (size_t)T;
    in.stimes_ptr   = mxGetPr(prhs[1]);
    in.sfreqs_ptr   = mxGetPr(prhs[2]);
    in.baseline_ptr = has_baseline ? mxGetPr(prhs[3]) : NULL;
    in.seg_time      = get_double_field(params, "seg_time", 30.0);
    in.downsample_f  = get_u32_field(params, "downsample_f", 1);
    in.downsample_t  = get_u32_field(params, "downsample_t", 1);
    in.merge_thresh  = get_double_field(params, "merge_thresh", 11.0);
    in.max_merges    = INFINITY;
    in.trim_vol_thresh = get_double_field(params, "trim_vol", 0.8);
    /* trim_shift: match MATLAB's global min(spect,[],'all') behavior.
     * If the caller didn't provide it, leave NAN so Rust falls back to
     * per-segment min (pydynamo default). The MATLAB dispatcher in
     * runSegmentedData.m computes the global min and passes it. */
    in.trim_shift_val  = get_double_field(params, "trim_shift", NAN);
    in.dur_min   = get_double_field(params, "dur_min", 0.0);
    in.dur_max   = get_double_field(params, "dur_max", INFINITY);
    in.bw_min    = get_double_field(params, "bw_min",  0.0);
    in.bw_max    = get_double_field(params, "bw_max",  INFINITY);
    in.freq_min  = get_double_field(params, "freq_min", -INFINITY);
    in.freq_max  = get_double_field(params, "freq_max",  INFINITY);
    in.ht_db_min = get_double_field(params, "ht_db_min", -INFINITY);
    /* expand_labels_distance: 0 = MATLAB paint-in-label-order semantics
     * (8-conn 1-px dilation, higher labels overwrite lower — exactly
     * matches extractTFPeaks.m + Ldata2graph.m). N>0 = skimage-style BFS.
     * Default 0 after bisection audit 2026-04-21 confirmed this closes
     * the +2% peak-count gap vs MATLAB. */
    in.expand_labels_distance = get_u32_field(params, "expand_labels_distance", 0);

    /* Single-line 10% progress ticks printed from the MAIN MATLAB thread.
     * Rust fires progress_callback (on rayon workers) with atomic updates
     * only; this main thread polls the atomics and does the printing.
     * show_pbar=false disables the register/poll entirely and the extract
     * still runs on the background thread — the thread architecture is
     * always used so Rust panics propagate uniformly. */
    bool show_pbar = get_bool_field(params, "show_pbar", true);
    atomic_store_explicit(&g_done,   0, memory_order_relaxed);
    atomic_store_explicit(&g_total,  0, memory_order_relaxed);
    atomic_store_explicit(&g_active, true, memory_order_release);
    struct timespec t_start;
    clock_gettime(CLOCK_MONOTONIC, &t_start);
    int last_tick_pct = 0;
    if (show_pbar) {
        mexPrintf("  Extracting TF peaks:");
        in.progress_cb = progress_callback;
    } else {
        in.progress_cb = NULL;
    }

    ExtractTfpeaksOut out; memset(&out, 0, sizeof(out));
    ExtractThreadArgs args = { &in, &out, 0 };
    pthread_t extract_tid;
    if (pthread_create(&extract_tid, NULL, extract_thread_main, &args) != 0) {
        mxDestroyArray(spect_t);
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:thread",
            "pthread_create failed");
    }

    /* Main thread: poll the atomic counter and mexPrintf on 10% bucket
     * boundary crossings. Poll every 100 ms — enough to feel live, not
     * enough to spam mexPrintf or CPU-poll. */
    const struct timespec poll_interval = { .tv_sec = 0, .tv_nsec = 100000000L };
    while (atomic_load_explicit(&g_active, memory_order_acquire)) {
        nanosleep(&poll_interval, NULL);
        if (show_pbar) {
            uint32_t done  = atomic_load_explicit(&g_done,  memory_order_relaxed);
            uint32_t total = atomic_load_explicit(&g_total, memory_order_relaxed);
            if (total > 0) {
                int pct = (int)((uint64_t)done * 100 / (uint64_t)total);
                int bucket = (pct / 10) * 10;
                while (last_tick_pct < bucket && last_tick_pct < 100) {
                    last_tick_pct += 10;
                    mexPrintf(" %d%%", last_tick_pct);
                    mexEvalString("drawnow('limitrate');");  /* flush to cmd window */
                }
            }
        }
    }
    pthread_join(extract_tid, NULL);
    mxDestroyArray(spect_t);
    int rc = args.rc;

    if (show_pbar) {
        while (last_tick_pct < 100) {
            last_tick_pct += 10;
            mexPrintf(" %d%%", last_tick_pct);
        }
        struct timespec t_end;
        clock_gettime(CLOCK_MONOTONIC, &t_end);
        double elapsed = (double)(t_end.tv_sec - t_start.tv_sec)
                       + (double)(t_end.tv_nsec - t_start.tv_nsec) * 1e-9;
        mexPrintf("  [%.1fs]\n", elapsed);
    }

    if (rc != 0) {
        mexErrMsgIdAndTxt("dynamo:extract_tfpeaks_mex:rust_error",
            "dynamo_extract_tfpeaks returned error code %d.", rc);
    }

    /* Build output struct */
    const char *fields[] = {
        "PeakTime", "PeakFrequency", "Duration", "Bandwidth",
        "Height", "Volume", "SegmentNum", "BoundingBox"
    };
    const int nfields = sizeof(fields) / sizeof(fields[0]);
    mxArray *result = mxCreateStructMatrix(1, 1, nfields, fields);
    size_t n = out.n_peaks;
    mxSetField(result, 0, "PeakTime",      take_rust_f64(out.peak_time, n));
    mxSetField(result, 0, "PeakFrequency", take_rust_f64(out.peak_freq, n));
    mxSetField(result, 0, "Duration",      take_rust_f64(out.duration,  n));
    mxSetField(result, 0, "Bandwidth",     take_rust_f64(out.bandwidth, n));
    mxSetField(result, 0, "Height",        take_rust_f64(out.height,    n));
    mxSetField(result, 0, "Volume",        take_rust_f64(out.volume,    n));
    mxSetField(result, 0, "SegmentNum",    take_rust_f64(out.segment_num, n));
    mxSetField(result, 0, "BoundingBox",   take_rust_bbox(out.bounding_box, n));

    /* labels: (F, T) int64 row-major from Rust. Emit as MATLAB (F, T)
     * int64 column-major if the caller requested it. Transpose-copy. */
    if (nlhs >= 2 && out.labels != NULL && out.n_label_elems == F * T) {
        mxArray *labels_mx = mxCreateNumericMatrix((mwSize)F, (mwSize)T, mxINT64_CLASS, mxREAL);
        int64_t *dst = (int64_t *)mxGetData(labels_mx);
        const int64_t *src = out.labels;
        /* row-major [r*T + c] → col-major [c*F + r] */
        for (size_t r = 0; r < F; ++r) {
            for (size_t c = 0; c < T; ++c) {
                dst[c * F + r] = src[r * T + c];
            }
        }
        plhs[1] = labels_mx;
    }
    if (out.labels != NULL && out.n_label_elems > 0) {
        dynamo_free_buffer_i64(out.labels, out.n_label_elems);
    }

    plhs[0] = result;
}
