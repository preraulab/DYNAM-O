/*
 * so_power_mex.c — MATLAB bridge to dynamo_rs::dynamo_so_power.
 *
 * Signature from MATLAB:
 *     [SOpower_norm, SOpower_times, SOpower_stages, ptile] = so_power_mex( ...
 *         so_spect, stimes, sfreqs, eeg_times, isexcluded, ...
 *         stage_times, stage_vals, time_range, outlier_threshold, ...
 *         norm_method, retain_fs)
 *
 *     so_spect            : F x T double (MATLAB column-major; SO-band spectrogram)
 *     stimes              : 1xT or Tx1 double (window-center times)
 *     sfreqs              : 1xF or Fx1 double (frequency bin centers)
 *     eeg_times           : 1xN or Nx1 double
 *     isexcluded          : 1xN or Nx1 logical/uint8
 *     stage_times         : 1xS or Sx1 double (may be empty)
 *     stage_vals          : 1xS or Sx1 double
 *     time_range          : 1x2 double  ([t_lo t_hi])
 *     outlier_threshold   : scalar double (z-score cutoff; 3.0 in pydynamo)
 *     norm_method         : char/string  ('p2shift1234', 'percent', 'none', ...)
 *     retain_fs           : logical/scalar (true => output upsampled to eeg_times)
 *
 *     SOpower_norm        : M x 1 double (M = retain_fs ? N : T)
 *     SOpower_times       : M x 1 double
 *     SOpower_stages      : M x 1 double
 *     ptile               : [] | scalar | 1x2 (matches Rust PtileUsed)
 *
 * Spect transposed column-major -> row-major before calling Rust.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static uint8_t *coerce_u8_mask(const mxArray *a, size_t expected_len, uint8_t *scratch) {
    size_t n = mxGetNumberOfElements(a);
    if (n != expected_len) {
        mexErrMsgIdAndTxt("dynamo:so_power_mex:dims",
            "mask length %d != expected %d", (int)n, (int)expected_len);
    }
    if (mxIsLogical(a)) {
        const mxLogical *src = mxGetLogicals(a);
        for (size_t i = 0; i < n; ++i) scratch[i] = src[i] ? 1u : 0u;
        return scratch;
    } else if (mxIsUint8(a)) {
        memcpy(scratch, mxGetData(a), n);
        return scratch;
    } else if (mxIsDouble(a)) {
        const double *src = mxGetPr(a);
        for (size_t i = 0; i < n; ++i) scratch[i] = src[i] != 0.0 ? 1u : 0u;
        return scratch;
    }
    mexErrMsgIdAndTxt("dynamo:so_power_mex:badInput",
        "isexcluded must be logical, uint8, or double.");
    return NULL;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 11) {
        mexErrMsgIdAndTxt("dynamo:so_power_mex:nrhs",
            "11 inputs required. See so_power_mex source header.");
    }
    if (nlhs > 4) {
        mexErrMsgIdAndTxt("dynamo:so_power_mex:nlhs",
            "At most 4 outputs.");
    }
    const int double_idx[] = {0, 1, 2, 3, 5, 6, 7, 8};
    const char *double_names[] = {"so_spect","stimes","sfreqs","eeg_times",
                                  "stage_times","stage_vals","time_range","outlier_threshold"};
    for (size_t k = 0; k < sizeof(double_idx)/sizeof(double_idx[0]); ++k) {
        const mxArray *p = prhs[double_idx[k]];
        if (!mxIsDouble(p) || mxIsComplex(p)) {
            mexErrMsgIdAndTxt("dynamo:so_power_mex:badInput",
                "Input %d (%s) must be real double.", double_idx[k] + 1, double_names[k]);
        }
    }

    size_t F = mxGetM(prhs[0]);
    size_t T = mxGetN(prhs[0]);
    if (mxGetNumberOfElements(prhs[1]) != T) {
        mexErrMsgIdAndTxt("dynamo:so_power_mex:dims",
            "stimes length (%d) != size(so_spect, 2) (%d).",
            (int)mxGetNumberOfElements(prhs[1]), (int)T);
    }
    if (mxGetNumberOfElements(prhs[2]) != F) {
        mexErrMsgIdAndTxt("dynamo:so_power_mex:dims",
            "sfreqs length (%d) != size(so_spect, 1) (%d).",
            (int)mxGetNumberOfElements(prhs[2]), (int)F);
    }
    size_t N = mxGetNumberOfElements(prhs[3]);

    /* Transpose column-major (F, T) to row-major (F, T). */
    const double *spect_cm = mxGetPr(prhs[0]);
    double *spect_rm = (double *)mxMalloc(F * T * sizeof(double));
    for (size_t f = 0; f < F; ++f)
        for (size_t t = 0; t < T; ++t)
            spect_rm[f * T + t] = spect_cm[t * F + f];

    uint8_t *excl_scratch = (uint8_t *)mxMalloc(N);
    uint8_t *excl = coerce_u8_mask(prhs[4], N, excl_scratch);

    size_t S = mxGetNumberOfElements(prhs[5]);
    if (mxGetNumberOfElements(prhs[6]) != S) {
        mxFree(spect_rm); mxFree(excl_scratch);
        mexErrMsgIdAndTxt("dynamo:so_power_mex:dims",
            "stage_times and stage_vals must have matching length.");
    }

    if (mxGetNumberOfElements(prhs[7]) != 2) {
        mxFree(spect_rm); mxFree(excl_scratch);
        mexErrMsgIdAndTxt("dynamo:so_power_mex:dims",
            "time_range must be 1x2.");
    }
    const double *time_range = mxGetPr(prhs[7]);
    double outlier_thresh = mxGetScalar(prhs[8]);

    char nm_buf[64];
    if (!mxIsChar(prhs[9])) {
        mxFree(spect_rm); mxFree(excl_scratch);
        mexErrMsgIdAndTxt("dynamo:so_power_mex:badInput",
            "norm_method (input 10) must be a string.");
    }
    mxGetString(prhs[9], nm_buf, sizeof(nm_buf));

    uint8_t retain_fs = 0u;
    if (mxIsLogical(prhs[10]) || mxIsNumeric(prhs[10])) {
        retain_fs = mxGetScalar(prhs[10]) != 0.0 ? 1u : 0u;
    } else {
        mxFree(spect_rm); mxFree(excl_scratch);
        mexErrMsgIdAndTxt("dynamo:so_power_mex:badInput",
            "retain_fs (input 11) must be logical or numeric.");
    }

    struct SoPowerIn in;
    in.spect_ptr         = spect_rm;
    in.n_freqs           = F;
    in.n_times           = T;
    in.stimes_ptr        = mxGetPr(prhs[1]);
    in.sfreqs_ptr        = mxGetPr(prhs[2]);
    in.eeg_times_ptr     = mxGetPr(prhs[3]);
    in.n_data            = N;
    in.isexcluded_ptr    = excl;
    in.stage_times_ptr   = S ? mxGetPr(prhs[5]) : NULL;
    in.stage_vals_ptr    = S ? mxGetPr(prhs[6]) : NULL;
    in.n_stages          = S;
    in.time_range_lo     = time_range[0];
    in.time_range_hi     = time_range[1];
    in.outlier_threshold = outlier_thresh;
    in.retain_fs         = retain_fs;
    in.norm_method_ptr   = (const uint8_t *)nm_buf;
    in.norm_method_len   = strlen(nm_buf);

    struct SoPowerOut out;
    int rc = dynamo_so_power(&in, &out);

    mxFree(spect_rm);
    mxFree(excl_scratch);

    if (rc != 0) {
        if (out.so_power_norm_ptr)   dynamo_free_buffer_f64(out.so_power_norm_ptr,   out.n_out);
        if (out.so_power_times_ptr)  dynamo_free_buffer_f64(out.so_power_times_ptr,  out.n_out);
        if (out.so_power_stages_ptr) dynamo_free_buffer_f64(out.so_power_stages_ptr, out.n_out);
        mexErrMsgIdAndTxt("dynamo:so_power_mex:rust_error",
            "dynamo_so_power returned error code %d.", rc);
    }

    size_t M = out.n_out;
    plhs[0] = mxCreateDoubleMatrix((mwSize)M, 1, mxREAL);
    if (M > 0) memcpy(mxGetPr(plhs[0]), out.so_power_norm_ptr, M * sizeof(double));
    if (nlhs >= 2) {
        plhs[1] = mxCreateDoubleMatrix((mwSize)M, 1, mxREAL);
        if (M > 0) memcpy(mxGetPr(plhs[1]), out.so_power_times_ptr, M * sizeof(double));
    }
    if (nlhs >= 3) {
        plhs[2] = mxCreateDoubleMatrix((mwSize)M, 1, mxREAL);
        if (M > 0) memcpy(mxGetPr(plhs[2]), out.so_power_stages_ptr, M * sizeof(double));
    }
    if (nlhs >= 4) {
        if (out.ptile_kind == 0)      plhs[3] = mxCreateDoubleMatrix(0, 0, mxREAL);
        else if (out.ptile_kind == 1) plhs[3] = mxCreateDoubleScalar(out.ptile_value[0]);
        else {
            plhs[3] = mxCreateDoubleMatrix(1, 2, mxREAL);
            mxGetPr(plhs[3])[0] = out.ptile_value[0];
            mxGetPr(plhs[3])[1] = out.ptile_value[1];
        }
    }

    dynamo_free_buffer_f64(out.so_power_norm_ptr,   M);
    dynamo_free_buffer_f64(out.so_power_times_ptr,  M);
    dynamo_free_buffer_f64(out.so_power_stages_ptr, M);
}
