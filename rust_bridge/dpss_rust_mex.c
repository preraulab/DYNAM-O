/*
 * dpss_rust_mex.c — MATLAB bridge to dynamo_rs::dynamo_dpss
 *
 * Signature from MATLAB:
 *     [tapers, ratios] = dpss_rust_mex(n, nw, k)
 *
 *     n       : scalar double  (window length, >=1)
 *     nw      : scalar double  (time-half-bandwidth, >0)
 *     k       : scalar double  (number of tapers, 1 <= k <= n)
 *
 *     tapers  : N x K double  (column k is the k-th Slepian sequence,
 *                              matching MATLAB's dpss(N, NW, K) output)
 *     ratios  : K x 1 double  (concentration ratios in (0, 1])
 *
 * Rust ABI hands back row-major (K, N) — we transpose into MATLAB's
 * (N, K) column-major output here so callers get MATLAB-native layout.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 3) {
        mexErrMsgIdAndTxt("dynamo:dpss_rust_mex:nrhs",
            "3 inputs required: n, nw, k.");
    }
    if (nlhs > 2) {
        mexErrMsgIdAndTxt("dynamo:dpss_rust_mex:nlhs",
            "At most 2 outputs: tapers, ratios.");
    }
    for (int i = 0; i < 3; ++i) {
        if (!mxIsDouble(prhs[i]) || mxIsComplex(prhs[i]) || mxGetNumberOfElements(prhs[i]) != 1) {
            mexErrMsgIdAndTxt("dynamo:dpss_rust_mex:badInput",
                "All inputs must be real-double scalars.");
        }
    }

    double n_d  = mxGetScalar(prhs[0]);
    double nw   = mxGetScalar(prhs[1]);
    double k_d  = mxGetScalar(prhs[2]);
    if (n_d < 1.0 || k_d < 1.0 || k_d > n_d || !(nw > 0.0)) {
        mexErrMsgIdAndTxt("dynamo:dpss_rust_mex:badInput",
            "Need n >= 1, 1 <= k <= n, nw > 0.");
    }
    size_t n = (size_t)n_d;
    size_t k = (size_t)k_d;

    /* Scratch buffer for row-major (K, N) tapers as Rust hands them back. */
    double *tapers_rm = (double *)mxMalloc(k * n * sizeof(double));

    /* MATLAB output: (N, K) double, column-major. Allocate up front. */
    mxArray *tapers_mat = mxCreateDoubleMatrix((mwSize)n, (mwSize)k, mxREAL);
    mxArray *ratios_mat = mxCreateDoubleMatrix((mwSize)k, 1, mxREAL);

    int rc = dynamo_dpss(n, nw, k, tapers_rm, mxGetPr(ratios_mat));

    if (rc != 0) {
        mxFree(tapers_rm);
        mxDestroyArray(tapers_mat);
        mxDestroyArray(ratios_mat);
        mexErrMsgIdAndTxt("dynamo:dpss_rust_mex:rust_error",
            "dynamo_dpss returned error code %d.", rc);
    }

    /* Transpose row-major (K, N) -> column-major (N, K). MATLAB column-
     * major (N, K) at (i, j) lives at j*N + i. Rust row-major (K, N) at
     * (j, i) lives at j*N + i — so the in-memory layout is actually
     * identical (both pack the i-axis fastest with stride 1). The
     * "rows are tapers" Rust convention equals "columns are tapers" in
     * MATLAB without any byte-shuffle. Just memcpy. */
    memcpy(mxGetPr(tapers_mat), tapers_rm, k * n * sizeof(double));

    mxFree(tapers_rm);

    plhs[0] = tapers_mat;
    if (nlhs > 1) plhs[1] = ratios_mat; else mxDestroyArray(ratios_mat);
}
