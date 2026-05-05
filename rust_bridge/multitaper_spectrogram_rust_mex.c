/*
 * multitaper_spectrogram_rust_mex.c — MATLAB bridge to
 * dynamo_rs::dynamo_multitaper_spectrogram (multitaper_rs core).
 *
 * Drop-in numerical alternative to multitaper_spectrogram_mex.m (the
 * MATLAB-Coder-generated f32 MEX). The Rust path runs in f64; output
 * agrees with the Coder MEX up to f32 roundoff (~1e-7 relative).
 *
 * Signature from MATLAB:
 *     [spect, stimes, sfreqs] = multitaper_spectrogram_rust_mex( ...
 *         data, Fs, freq_range, taper_params, window_params, ...
 *         tapers, eigen_or_empty, nfft, detrend_opt, weighting)
 *
 *     data           : 1xN or Nx1 double
 *     Fs             : scalar double
 *     freq_range     : 1x2 double  [fmin, fmax]
 *     taper_params   : 1x2 double  [time_BW, num_tapers]   (informational; not consumed)
 *     window_params  : 1x2 double  [size_s, step_s]
 *     tapers         : (K x winsize) double, MATLAB `dpss`-style — caller computes
 *     eigen_or_empty : 1xK double (when weighting='eigen') or [] (when 'unity')
 *     nfft           : scalar double (positive integer)
 *     detrend_opt    : char 'linear' | 'constant' | 'off'
 *     weighting      : char 'unity' | 'eigen'
 *
 *     spect          : F x T double (MATLAB column-major; (freqs, times))
 *     stimes         : 1 x T double
 *     sfreqs         : F x 1 double
 *
 * Layout: Rust returns row-major (F, T) in spect_ptr. We transpose into
 * MATLAB's column-major on the way out.
 *
 * Memory: Rust outputs are Box::leak-allocated; the wrapper memcpy's into
 * mxArrays then calls dynamo_free_buffer_f64 on each pointer.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdint.h>
#include <string.h>
#include <stdbool.h>

static uint32_t parse_detrend(const mxArray *a) {
    if (!mxIsChar(a)) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
            "detrend_opt must be 'linear', 'constant', or 'off'.");
    }
    char buf[16];
    if (mxGetString(a, buf, sizeof(buf)) != 0) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
            "detrend_opt string too long.");
    }
    if (strcmp(buf, "linear")   == 0) return 1;
    if (strcmp(buf, "constant") == 0) return 2;
    if (strcmp(buf, "off")      == 0) return 0;
    mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
        "detrend_opt must be 'linear', 'constant', or 'off' (got '%s').", buf);
    return 0; /* unreachable */
}

static uint32_t parse_weighting(const mxArray *a) {
    if (!mxIsChar(a)) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
            "weighting must be 'unity' or 'eigen'.");
    }
    char buf[16];
    if (mxGetString(a, buf, sizeof(buf)) != 0) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
            "weighting string too long.");
    }
    if (strcmp(buf, "unity") == 0) return 0;
    if (strcmp(buf, "eigen") == 0) return 1;
    mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
        "weighting must be 'unity' or 'eigen' (got '%s').", buf);
    return 0;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 10) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:nrhs",
            "10 inputs: data, Fs, freq_range, taper_params, window_params, "
            "tapers, eigen_or_empty, nfft, detrend_opt, weighting");
    }
    if (nlhs > 3) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:nlhs",
            "At most 3 outputs (spect, stimes, sfreqs).");
    }

    /* --- data ---
     * Accept either real double or real single. Real EDFs often arrive
     * as single after read_EDF (the Coder MEX expects single). We need
     * f64 for multitaper_rs, so up-cast a single input into a temporary
     * f64 buffer; for double input, use the pointer in place. */
    if (mxIsComplex(prhs[0]) || (!mxIsDouble(prhs[0]) && !mxIsSingle(prhs[0]))) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
            "data must be real double or real single.");
    }
    size_t n_data = mxGetNumberOfElements(prhs[0]);
    double *data_d = NULL;
    int data_owned = 0;
    if (mxIsDouble(prhs[0])) {
        data_d = mxGetPr(prhs[0]);
    } else {
        data_d = (double *)mxMalloc(n_data * sizeof(double));
        const float *src = (const float *)mxGetData(prhs[0]);
        for (size_t i = 0; i < n_data; ++i) data_d[i] = (double)src[i];
        data_owned = 1;
    }

    /* --- Fs --- */
    if (!mxIsDouble(prhs[1]) || mxGetNumberOfElements(prhs[1]) != 1) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput", "Fs must be a scalar double.");
    }
    double fs = mxGetScalar(prhs[1]);

    /* --- freq_range --- */
    if (!mxIsDouble(prhs[2]) || mxGetNumberOfElements(prhs[2]) != 2) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput", "freq_range must be 1x2 double.");
    }
    const double *frange = mxGetPr(prhs[2]);
    double freq_min = frange[0], freq_max = frange[1];

    /* --- taper_params (informational; ignored) --- */
    if (!mxIsDouble(prhs[3]) || mxGetNumberOfElements(prhs[3]) != 2) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput", "taper_params must be 1x2 double.");
    }

    /* --- window_params --- */
    if (!mxIsDouble(prhs[4]) || mxGetNumberOfElements(prhs[4]) != 2) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput", "window_params must be 1x2 double.");
    }
    const double *wparams = mxGetPr(prhs[4]);
    double winsize_s = wparams[0], winstep_s = wparams[1];

    /* --- tapers (K x winsize) --- */
    if (!mxIsDouble(prhs[5]) || mxIsComplex(prhs[5])) {
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput", "tapers must be real double.");
    }
    /* MATLAB `dpss(N, NW)` returns (winsize, K) — we want (K, winsize)
     * row-major in Rust. Transpose into a flat row-major buffer. */
    size_t taper_M = mxGetM(prhs[5]); /* MATLAB rows = winsize */
    size_t taper_N = mxGetN(prhs[5]); /* MATLAB cols = K        */
    size_t winsize_samples = taper_M;
    size_t n_tapers = taper_N;
    const double *tapers_cm = mxGetPr(prhs[5]);
    double *tapers_rm = (double *)mxMalloc(n_tapers * winsize_samples * sizeof(double));
    /* Out: row k of (K, winsize) at tapers_rm[k*winsize + i].
     * In:  MATLAB col k of (winsize, K) at tapers_cm[k*winsize + i] (column-major). */
    for (size_t k = 0; k < n_tapers; ++k) {
        memcpy(tapers_rm + k * winsize_samples,
               tapers_cm + k * winsize_samples,
               winsize_samples * sizeof(double));
    }

    /* --- eigen_or_empty --- */
    const double *eigen_ptr = NULL;
    size_t eigen_len = 0;
    if (!mxIsEmpty(prhs[6])) {
        if (!mxIsDouble(prhs[6]) || mxIsComplex(prhs[6])) {
            mxFree(tapers_rm);
            mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
                "eigen must be real double or [].");
        }
        if (mxGetNumberOfElements(prhs[6]) != n_tapers) {
            mxFree(tapers_rm);
            mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput",
                "eigen length (%d) must equal num_tapers (%d).",
                (int)mxGetNumberOfElements(prhs[6]), (int)n_tapers);
        }
        eigen_ptr = mxGetPr(prhs[6]);
        eigen_len = n_tapers;
    }

    /* --- nfft --- */
    if (!mxIsDouble(prhs[7]) || mxGetNumberOfElements(prhs[7]) != 1) {
        mxFree(tapers_rm);
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:badInput", "nfft must be a scalar double.");
    }
    size_t nfft = (size_t)mxGetScalar(prhs[7]);

    /* --- detrend_opt + weighting --- */
    uint32_t detrend = parse_detrend(prhs[8]);
    uint32_t weighting = parse_weighting(prhs[9]);

    /* --- Build input struct + call Rust --- */
    MtsIn in;
    memset(&in, 0, sizeof(in));
    in.data_ptr      = data_d;
    in.n_data        = n_data;
    in.fs            = fs;
    in.tapers_ptr    = tapers_rm;
    in.n_tapers      = n_tapers;
    in.winsize       = winsize_samples;
    in.eigen_ptr     = eigen_ptr;
    in.eigen_len     = eigen_len;
    in.freq_min      = freq_min;
    in.freq_max      = freq_max;
    in.window_size_s = winsize_s;
    in.window_step_s = winstep_s;
    in.nfft          = nfft;
    in.detrend       = detrend;
    in.weighting     = weighting;

    MtsOut out;
    memset(&out, 0, sizeof(out));

    int rc = dynamo_multitaper_spectrogram(&in, &out);
    mxFree(tapers_rm);
    if (data_owned) mxFree(data_d);

    if (rc != 0) {
        /* Free anything Rust may have written into out before erroring. */
        if (out.spect_ptr)  dynamo_free_buffer_f64(out.spect_ptr,  out.n_freqs_out * out.n_windows);
        if (out.stimes_ptr) dynamo_free_buffer_f64(out.stimes_ptr, out.n_windows);
        if (out.sfreqs_ptr) dynamo_free_buffer_f64(out.sfreqs_ptr, out.n_freqs_out);
        mexErrMsgIdAndTxt("dynamo:mts_rust_mex:rust_error",
            "dynamo_multitaper_spectrogram returned error code %d.", rc);
    }

    /* --- Build outputs ---
     * Rust gives row-major (F, T) at out.spect_ptr. MATLAB wants
     * column-major (F, T): element (f, t) at dst[t*F + f]. Source row-major
     * has (f, t) at src[f*T + t]. Transpose. */
    size_t F = out.n_freqs_out;
    size_t T = out.n_windows;
    plhs[0] = mxCreateDoubleMatrix((mwSize)F, (mwSize)T, mxREAL);
    if (F > 0 && T > 0) {
        double *dst = mxGetPr(plhs[0]);
        const double *src = out.spect_ptr;
        for (size_t f = 0; f < F; ++f) {
            for (size_t t = 0; t < T; ++t) {
                dst[t * F + f] = src[f * T + t];
            }
        }
    }
    if (nlhs >= 2) {
        plhs[1] = mxCreateDoubleMatrix(1, (mwSize)T, mxREAL);
        if (T > 0) memcpy(mxGetPr(plhs[1]), out.stimes_ptr, T * sizeof(double));
    }
    if (nlhs >= 3) {
        plhs[2] = mxCreateDoubleMatrix((mwSize)F, 1, mxREAL);
        if (F > 0) memcpy(mxGetPr(plhs[2]), out.sfreqs_ptr, F * sizeof(double));
    }

    /* Release Rust-side buffers (bytes already copied). */
    dynamo_free_buffer_f64(out.spect_ptr,  F * T);
    dynamo_free_buffer_f64(out.stimes_ptr, T);
    dynamo_free_buffer_f64(out.sfreqs_ptr, F);
}
