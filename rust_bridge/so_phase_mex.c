/*
 * so_phase_mex.c — MATLAB bridge to dynamo_rs::dynamo_so_phase.
 *
 * Signature from MATLAB:
 *     [SOphase, times, stages, filtdata] = so_phase_mex( ...
 *         eeg, eeg_times, isexcluded, sos, stage_times, stage_vals)
 *
 *     eeg            : Nx1 or 1xN double  (raw EEG)
 *     eeg_times      : Nx1 or 1xN double
 *     isexcluded     : Nx1 or 1xN logical/uint8
 *     sos            : K x 6 double  (scipy SOS layout: [b0 b1 b2 a0 a1 a2])
 *     stage_times    : Sx1 or 1xS double  (may be empty)
 *     stage_vals     : Sx1 or 1xS double
 *
 *     SOphase        : Nx1 double  (unwrapped phase; NaN at excluded samples)
 *     times          : Nx1 double  (echo of eeg_times)
 *     stages         : Nx1 double  (0 outside staging range)
 *     filtdata       : Nx1 double  (filtered EEG; NaN at excluded samples)
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static uint8_t *coerce_u8_mask(const mxArray *a, size_t expected_len, uint8_t *scratch) {
    size_t n = mxGetNumberOfElements(a);
    if (n != expected_len) {
        mexErrMsgIdAndTxt("dynamo:so_phase_mex:dims",
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
    mexErrMsgIdAndTxt("dynamo:so_phase_mex:badInput",
        "isexcluded must be logical, uint8, or double.");
    return NULL;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 6) {
        mexErrMsgIdAndTxt("dynamo:so_phase_mex:nrhs",
            "6 inputs required: eeg, eeg_times, isexcluded, sos, stage_times, stage_vals.");
    }
    if (nlhs > 4) {
        mexErrMsgIdAndTxt("dynamo:so_phase_mex:nlhs",
            "At most 4 outputs.");
    }
    const int double_idx[] = {0, 1, 3, 4, 5};
    const char *double_names[] = {"eeg", "eeg_times", "sos", "stage_times", "stage_vals"};
    for (size_t k = 0; k < sizeof(double_idx)/sizeof(double_idx[0]); ++k) {
        const mxArray *p = prhs[double_idx[k]];
        if (!mxIsDouble(p) || mxIsComplex(p)) {
            mexErrMsgIdAndTxt("dynamo:so_phase_mex:badInput",
                "Input %d (%s) must be real double.", double_idx[k] + 1, double_names[k]);
        }
    }

    size_t N = mxGetNumberOfElements(prhs[0]);
    if (mxGetNumberOfElements(prhs[1]) != N) {
        mexErrMsgIdAndTxt("dynamo:so_phase_mex:dims",
            "eeg_times length (%d) != eeg length (%d).",
            (int)mxGetNumberOfElements(prhs[1]), (int)N);
    }
    uint8_t *excl_scratch = (uint8_t *)mxMalloc(N);
    uint8_t *excl = coerce_u8_mask(prhs[2], N, excl_scratch);

    /* SOS: MATLAB column-major (K, 6) — transpose to row-major (K, 6). */
    size_t K_sos = mxGetM(prhs[3]);
    size_t cols  = mxGetN(prhs[3]);
    if (cols != 6) {
        mxFree(excl_scratch);
        mexErrMsgIdAndTxt("dynamo:so_phase_mex:dims",
            "sos must be K x 6 (got %d x %d).", (int)K_sos, (int)cols);
    }
    const double *sos_cm = mxGetPr(prhs[3]);
    double *sos_rm = (double *)mxMalloc(K_sos * 6 * sizeof(double));
    for (size_t k = 0; k < K_sos; ++k)
        for (size_t j = 0; j < 6; ++j)
            sos_rm[k * 6 + j] = sos_cm[j * K_sos + k];

    size_t S = mxGetNumberOfElements(prhs[4]);
    if (mxGetNumberOfElements(prhs[5]) != S) {
        mxFree(sos_rm); mxFree(excl_scratch);
        mexErrMsgIdAndTxt("dynamo:so_phase_mex:dims",
            "stage_times and stage_vals must have matching length.");
    }

    struct SoPhaseIn in;
    in.eeg_ptr         = mxGetPr(prhs[0]);
    in.eeg_times_ptr   = mxGetPr(prhs[1]);
    in.isexcluded_ptr  = excl;
    in.n_data          = N;
    in.sos_ptr         = sos_rm;
    in.n_sections      = K_sos;
    in.stage_times_ptr = S ? mxGetPr(prhs[4]) : NULL;
    in.stage_vals_ptr  = S ? mxGetPr(prhs[5]) : NULL;
    in.n_stages        = S;

    struct SoPhaseOut out;
    int rc = dynamo_so_phase(&in, &out);

    mxFree(sos_rm);
    mxFree(excl_scratch);

    if (rc != 0) {
        if (out.so_phase_ptr)        dynamo_free_buffer_f64(out.so_phase_ptr,        out.n_out);
        if (out.so_phase_times_ptr)  dynamo_free_buffer_f64(out.so_phase_times_ptr,  out.n_out);
        if (out.so_phase_stages_ptr) dynamo_free_buffer_f64(out.so_phase_stages_ptr, out.n_out);
        if (out.filtdata_ptr)        dynamo_free_buffer_f64(out.filtdata_ptr,        out.n_out);
        mexErrMsgIdAndTxt("dynamo:so_phase_mex:rust_error",
            "dynamo_so_phase returned error code %d.", rc);
    }

    size_t M = out.n_out;
    plhs[0] = mxCreateDoubleMatrix((mwSize)M, 1, mxREAL);
    if (M > 0) memcpy(mxGetPr(plhs[0]), out.so_phase_ptr, M * sizeof(double));
    if (nlhs >= 2) {
        plhs[1] = mxCreateDoubleMatrix((mwSize)M, 1, mxREAL);
        if (M > 0) memcpy(mxGetPr(plhs[1]), out.so_phase_times_ptr, M * sizeof(double));
    }
    if (nlhs >= 3) {
        plhs[2] = mxCreateDoubleMatrix((mwSize)M, 1, mxREAL);
        if (M > 0) memcpy(mxGetPr(plhs[2]), out.so_phase_stages_ptr, M * sizeof(double));
    }
    if (nlhs >= 4) {
        plhs[3] = mxCreateDoubleMatrix((mwSize)M, 1, mxREAL);
        if (M > 0) memcpy(mxGetPr(plhs[3]), out.filtdata_ptr, M * sizeof(double));
    }

    dynamo_free_buffer_f64(out.so_phase_ptr,        M);
    dynamo_free_buffer_f64(out.so_phase_times_ptr,  M);
    dynamo_free_buffer_f64(out.so_phase_stages_ptr, M);
    dynamo_free_buffer_f64(out.filtdata_ptr,        M);
}
