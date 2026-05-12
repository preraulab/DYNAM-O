/*
 * baseline_mex.c — MATLAB bridge to dynamo_rs::dynamo_compute_baseline.
 *
 * Signature from MATLAB:
 *     baseline = baseline_mex(spect, stimes, t_data, baseline_exclude, ...
 *                             baseline_range, baseline_ptile)
 *
 *     spect             : F x T double  (MATLAB column-major)
 *     stimes            : 1 x T or T x 1 double
 *     t_data            : 1 x N or N x 1 double
 *     baseline_exclude  : 1 x N or N x 1 logical/uint8
 *     baseline_range    : [lo hi] double (2 elements; pass [-Inf Inf] for no trim)
 *     baseline_ptile    : scalar double in [0, 100]
 *
 *     baseline          : F x 1 double  (matches computeBaseline.m output)
 *
 * Rust ABI expects spect in row-major (F, T) order; we transpose
 * MATLAB's column-major (F, T) into a scratch buffer before the call.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static uint8_t *logical_or_u8_as_u8(const mxArray *a, size_t expected_len, uint8_t *scratch) {
    size_t n = mxGetNumberOfElements(a);
    if (n != expected_len) {
        mexErrMsgIdAndTxt("dynamo:baseline_mex:dims",
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
    mexErrMsgIdAndTxt("dynamo:baseline_mex:badInput",
        "baseline_exclude must be logical, uint8, or double.");
    return NULL;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 6) {
        mexErrMsgIdAndTxt("dynamo:baseline_mex:nrhs",
            "6 inputs required: spect, stimes, t_data, baseline_exclude, baseline_range, baseline_ptile.");
    }
    if (nlhs > 1) {
        mexErrMsgIdAndTxt("dynamo:baseline_mex:nlhs",
            "At most 1 output: baseline.");
    }
    const int double_idx[] = {0, 1, 2, 4, 5};
    const char *double_names[] = {"spect", "stimes", "t_data", "baseline_range", "baseline_ptile"};
    for (size_t k = 0; k < sizeof(double_idx)/sizeof(double_idx[0]); ++k) {
        const mxArray *p = prhs[double_idx[k]];
        if (!mxIsDouble(p) || mxIsComplex(p)) {
            mexErrMsgIdAndTxt("dynamo:baseline_mex:badInput",
                "Input %d (%s) must be real double.", double_idx[k] + 1, double_names[k]);
        }
    }

    size_t F = mxGetM(prhs[0]);
    size_t T = mxGetN(prhs[0]);
    if (mxGetNumberOfElements(prhs[1]) != T) {
        mexErrMsgIdAndTxt("dynamo:baseline_mex:dims",
            "stimes length (%d) must equal size(spect, 2) (%d).",
            (int)mxGetNumberOfElements(prhs[1]), (int)T);
    }
    size_t N = mxGetNumberOfElements(prhs[2]);

    if (mxGetNumberOfElements(prhs[4]) != 2) {
        mexErrMsgIdAndTxt("dynamo:baseline_mex:dims",
            "baseline_range must have 2 elements.");
    }
    if (mxGetNumberOfElements(prhs[5]) != 1) {
        mexErrMsgIdAndTxt("dynamo:baseline_mex:dims",
            "baseline_ptile must be scalar.");
    }
    const double *range = mxGetPr(prhs[4]);
    double bl_lo = range[0];
    double bl_hi = range[1];
    double bl_ptile = mxGetScalar(prhs[5]);

    /* Transpose column-major (F, T) to row-major (F, T). */
    const double *spect_cm = mxGetPr(prhs[0]);
    double *spect_rm = (double *)mxMalloc(F * T * sizeof(double));
    for (size_t f = 0; f < F; ++f) {
        for (size_t t = 0; t < T; ++t) {
            spect_rm[f * T + t] = spect_cm[t * F + f];
        }
    }

    /* Normalize mask to u8. */
    uint8_t *excl_scratch = (uint8_t *)mxMalloc(N);
    uint8_t *excl = logical_or_u8_as_u8(prhs[3], N, excl_scratch);

    mxArray *baseline_mat = mxCreateDoubleMatrix((mwSize)F, 1, mxREAL);

    int rc = dynamo_compute_baseline(
        spect_rm, F, T,
        mxGetPr(prhs[1]),  /* stimes */
        mxGetPr(prhs[2]),  /* t_data */
        N,
        excl,
        bl_lo, bl_hi,
        bl_ptile,
        mxGetPr(baseline_mat));

    mxFree(spect_rm);
    mxFree(excl_scratch);

    if (rc != 0) {
        mxDestroyArray(baseline_mat);
        mexErrMsgIdAndTxt("dynamo:baseline_mex:rust_error",
            "dynamo_compute_baseline returned error code %d.", rc);
    }
    plhs[0] = baseline_mat;
}
