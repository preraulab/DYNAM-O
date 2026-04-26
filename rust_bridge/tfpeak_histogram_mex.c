/*
 * tfpeak_histogram_mex.cpp — MATLAB bridge to dynamo_rs::dynamo_tfpeak_histogram
 *
 * Signature from MATLAB:
 *     [c_mat, time_in_bin, prop_in_bin, peak_at_freq] = tfpeak_histogram_mex( ...
 *         c_metric, c_stages, c_dt, c_valid, c_valid_allstages, ...
 *         peak_freqs, peak_c, freq_edges, c_edges, opts_struct)
 *
 *     c_metric:            1xT double  (SOpower or SOphase timeseries)
 *     c_stages:            1xT double  (stage value at each c_metric sample)
 *     c_dt:                scalar double (timestep of c_metric)
 *     c_valid:             1xT logical or uint8 (inclusion mask)
 *     c_valid_allstages:   1xT logical or uint8
 *     peak_freqs:          Nx1 double
 *     peak_c:              Nx1 double (metric value at each peak)
 *     freq_edges:          2 x num_fbins double (col-major: row 0 = low edges, row 1 = high edges)
 *     c_edges:             2 x num_cbins double
 *     opts_struct fields:
 *       circular (logical, default false)
 *       circular_lo, circular_hi (double, default 0, 2*pi)
 *       norm_dim (int32, default 0)
 *       compute_rate (logical, default false)
 *       min_time_in_bin (double, default 0)
 *       min_peak_at_freq (int32, default 0)
 *
 *   Outputs are caller-allocated and written into by Rust.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static uint8_t *logical_or_u8_as_u8(const mxArray *a, size_t expected_len, uint8_t *scratch) {
    /* Accept either logical or uint8, writing expected_len bytes into scratch. */
    size_t n = mxGetNumberOfElements(a);
    if (n != expected_len) {
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:badInput",
            "mask length %d != expected %d", (int)n, (int)expected_len);
    }
    if (mxIsLogical(a)) {
        const mxLogical *src = mxGetLogicals(a);
        for (size_t i = 0; i < n; ++i) scratch[i] = src[i] ? 1u : 0u;
        return scratch;
    } else if (mxIsUint8(a)) {
        memcpy(scratch, mxGetData(a), n);
        return scratch;
    }
    mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:badInput",
        "mask must be logical or uint8");
    return NULL;   /* unreachable */
}

static double get_double_field(const mxArray *s, const char *name, double def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL || mxGetNumberOfElements(f) == 0) return def;
    return mxGetScalar(f);
}
static int32_t get_i32_field(const mxArray *s, const char *name, int32_t def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL || mxGetNumberOfElements(f) == 0) return def;
    return (int32_t)mxGetScalar(f);
}
static uint8_t get_bool_field(const mxArray *s, const char *name, bool def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL || mxGetNumberOfElements(f) == 0) return def ? 1u : 0u;
    return mxGetScalar(f) != 0.0 ? 1u : 0u;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 10) {
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:nrhs",
            "10 inputs required. See mex source header.");
    }
    if (nlhs > 4) {
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:nlhs",
            "At most 4 outputs: c_mat, time_in_bin, prop_in_bin, peak_at_freq.");
    }

    size_t n_times = mxGetNumberOfElements(prhs[0]);
    if (mxGetNumberOfElements(prhs[1]) != n_times) {
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:dims",
            "c_stages length must match c_metric length.");
    }
    double c_dt = mxGetScalar(prhs[2]);

    /* Normalize mask types to uint8 */
    uint8_t *c_valid_scratch = (uint8_t *)mxMalloc(n_times);
    uint8_t *c_valid_allstages_scratch = (uint8_t *)mxMalloc(n_times);
    uint8_t *c_valid = logical_or_u8_as_u8(prhs[3], n_times, c_valid_scratch);
    uint8_t *c_valid_all = logical_or_u8_as_u8(prhs[4], n_times, c_valid_allstages_scratch);

    size_t n_peaks = mxGetNumberOfElements(prhs[5]);
    if (mxGetNumberOfElements(prhs[6]) != n_peaks) {
        mxFree(c_valid_scratch); mxFree(c_valid_allstages_scratch);
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:dims",
            "peak_c length must match peak_freqs length.");
    }

    /* Edge matrices must be 2 x N row-major (Rust ABI expects row-major
     * with row 0 = low edges, row 1 = high edges). MATLAB column-major
     * 2xN has bytes [low0, high0, low1, high1, ...] — we need
     * [low0, low1, ..., lowN, high0, high1, ..., highN]. Transpose-copy. */
    const double *freq_edges_cm = mxGetPr(prhs[7]);
    const double *c_edges_cm    = mxGetPr(prhs[8]);
    if (mxGetM(prhs[7]) != 2 || mxGetM(prhs[8]) != 2) {
        mxFree(c_valid_scratch); mxFree(c_valid_allstages_scratch);
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:dims",
            "freq_edges and c_edges must each have 2 rows.");
    }
    size_t num_fbins = mxGetN(prhs[7]);
    size_t num_cbins = mxGetN(prhs[8]);

    double *freq_edges_rm = (double *)mxMalloc(2 * num_fbins * sizeof(double));
    for (size_t i = 0; i < num_fbins; ++i) {
        freq_edges_rm[0 * num_fbins + i] = freq_edges_cm[i * 2 + 0];
        freq_edges_rm[1 * num_fbins + i] = freq_edges_cm[i * 2 + 1];
    }
    double *c_edges_rm = (double *)mxMalloc(2 * num_cbins * sizeof(double));
    for (size_t i = 0; i < num_cbins; ++i) {
        c_edges_rm[0 * num_cbins + i] = c_edges_cm[i * 2 + 0];
        c_edges_rm[1 * num_cbins + i] = c_edges_cm[i * 2 + 1];
    }

    const mxArray *opts = prhs[9];
    if (!mxIsStruct(opts)) {
        mxFree(c_valid_scratch); mxFree(c_valid_allstages_scratch);
        mxFree(freq_edges_rm); mxFree(c_edges_rm);
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:badInput",
            "opts (input 10) must be a struct.");
    }
    uint8_t circular        = get_bool_field(opts, "circular", false);
    double  circular_lo     = get_double_field(opts, "circular_lo", 0.0);
    double  circular_hi     = get_double_field(opts, "circular_hi", 6.283185307179586);
    int32_t norm_dim        = get_i32_field(opts, "norm_dim", 0);
    uint8_t compute_rate    = get_bool_field(opts, "compute_rate", false);
    double  min_time_in_bin = get_double_field(opts, "min_time_in_bin", 0.0);
    int32_t min_peak_at_f   = get_i32_field(opts, "min_peak_at_freq", 0);

    /* Caller-allocated outputs. Returned to MATLAB in row-major-like layout
     * where num_cbins is the "rows" of the 2-D output. MATLAB would see the
     * data as (num_fbins, num_cbins) col-major once we reshape. */
    mxArray *c_mat        = mxCreateDoubleMatrix((mwSize)num_cbins, (mwSize)num_fbins, mxREAL);
    mxArray *time_in_bin  = mxCreateDoubleMatrix((mwSize)num_cbins, 5, mxREAL);
    mxArray *prop_in_bin  = mxCreateDoubleMatrix((mwSize)num_cbins, 5, mxREAL);
    mxArray *peak_at_freq = mxCreateDoubleMatrix((mwSize)num_fbins, 1, mxREAL);

    int rc = dynamo_tfpeak_histogram(
        mxGetPr(prhs[0]),  /* c_metric */
        mxGetPr(prhs[1]),  /* c_stages */
        c_dt,
        c_valid,
        c_valid_all,
        n_times,
        mxGetPr(prhs[5]),  /* peak_freqs */
        mxGetPr(prhs[6]),  /* peak_c */
        n_peaks,
        freq_edges_rm, num_fbins,
        c_edges_rm, num_cbins,
        circular,
        circular_lo, circular_hi,
        norm_dim,
        compute_rate,
        min_time_in_bin, min_peak_at_f,
        mxGetPr(c_mat),
        mxGetPr(time_in_bin),
        mxGetPr(prop_in_bin),
        mxGetPr(peak_at_freq)
    );

    mxFree(c_valid_scratch);
    mxFree(c_valid_allstages_scratch);
    mxFree(freq_edges_rm);
    mxFree(c_edges_rm);

    if (rc != 0) {
        mxDestroyArray(c_mat); mxDestroyArray(time_in_bin);
        mxDestroyArray(prop_in_bin); mxDestroyArray(peak_at_freq);
        mexErrMsgIdAndTxt("dynamo:tfpeak_histogram_mex:rust_error",
            "dynamo_tfpeak_histogram returned error code %d.", rc);
    }

    plhs[0] = c_mat;
    if (nlhs > 1) plhs[1] = time_in_bin;  else mxDestroyArray(time_in_bin);
    if (nlhs > 2) plhs[2] = prop_in_bin;  else mxDestroyArray(prop_in_bin);
    if (nlhs > 3) plhs[3] = peak_at_freq; else mxDestroyArray(peak_at_freq);
}
