/*
 * refine_peaks_mex.cpp  —  MATLAB bridge to dynamo_rs::dynamo_refine_peaks
 *
 * Signature from MATLAB:
 *     [refined_peak_freq, keep] = refine_peaks_mex( ...
 *         peak_time, peak_freq, bbox, data, fs, freq_range, ...
 *         window_size, dsfreqs)
 *
 *     peak_time:   Nx1 double
 *     peak_freq:   Nx1 double
 *     bbox:        Nx4 double  [t_tl, f_tl, width_s, height_Hz] per peak
 *                              (pydynamo BoundingBox format — same order
 *                              used by extract_tfpeaks_mex's output)
 *     data:        1xM double (raw signal)
 *     fs:          scalar double
 *     freq_range:  1x2 double [lo, hi]
 *     window_size: scalar double (seconds)
 *     dsfreqs:     scalar double (Hz)
 *
 * Outputs are caller-allocated (we mxCreate the buffers, hand their
 * pointers to Rust; Rust writes into them).
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdint.h>
#include <string.h>

static void check_double_vec(const mxArray *a, const char *name, size_t expected_len) {
    if (!mxIsDouble(a) || mxIsComplex(a)) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
                          "%s must be real double.", name);
    }
    if (mxGetNumberOfElements(a) != expected_len) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
                          "%s length must be %d.", name, (int)expected_len);
    }
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 8) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:nrhs",
            "8 inputs: peak_time, peak_freq, bbox, data, fs, freq_range, window_size, dsfreqs");
    }
    if (nlhs > 2) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:nlhs",
            "At most 2 outputs (refined_peak_freq, keep).");
    }

    size_t n = mxGetNumberOfElements(prhs[0]);
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0])) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
            "peak_time must be real double.");
    }
    check_double_vec(prhs[1], "peak_freq", n);

    if (!mxIsDouble(prhs[2]) || mxIsComplex(prhs[2]) ||
        mxGetM(prhs[2]) != n || mxGetN(prhs[2]) != 4) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
            "bbox must be Nx4 real double (N=%d).", (int)n);
    }

    if (!mxIsDouble(prhs[3]) || mxIsComplex(prhs[3])) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
            "data must be real double.");
    }
    size_t n_data = mxGetNumberOfElements(prhs[3]);

    if (!mxIsDouble(prhs[4]) || mxGetNumberOfElements(prhs[4]) != 1) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
            "fs must be a scalar double.");
    }
    double fs = mxGetScalar(prhs[4]);

    if (!mxIsDouble(prhs[5]) || mxGetNumberOfElements(prhs[5]) != 2) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
            "freq_range must be a 1x2 double.");
    }
    const double *freq_range = mxGetPr(prhs[5]);
    double freq_lo = freq_range[0];
    double freq_hi = freq_range[1];

    if (!mxIsDouble(prhs[6]) || mxGetNumberOfElements(prhs[6]) != 1) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
            "window_size must be a scalar double.");
    }
    double window_size = mxGetScalar(prhs[6]);

    if (!mxIsDouble(prhs[7]) || mxGetNumberOfElements(prhs[7]) != 1) {
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:badInput",
            "dsfreqs must be a scalar double.");
    }
    double dsfreqs = mxGetScalar(prhs[7]);

    /* bbox is MATLAB column-major Nx4 but the Rust ABI expects row-major
     * (each peak's 4 values contiguous). Transpose into a flat N*4 buffer. */
    const double *bbox_cm = mxGetPr(prhs[2]);
    double *bbox_rm = (double *)mxMalloc(n * 4 * sizeof(double));
    for (size_t i = 0; i < n; ++i) {
        for (size_t j = 0; j < 4; ++j) {
            bbox_rm[i * 4 + j] = bbox_cm[j * n + i];
        }
    }

    /* Caller-allocated output buffers. */
    mxArray *out_freq = mxCreateDoubleMatrix((mwSize)n, 1, mxREAL);
    mxArray *out_keep = mxCreateNumericMatrix((mwSize)n, 1, mxUINT8_CLASS, mxREAL);

    int rc = dynamo_refine_peaks(
        mxGetPr(prhs[0]),  /* peak_time */
        mxGetPr(prhs[1]),  /* peak_freq */
        bbox_rm,
        n,
        mxGetPr(prhs[3]),
        n_data,
        fs,
        freq_lo, freq_hi,
        window_size,
        dsfreqs,
        mxGetPr(out_freq),
        (uint8_t *)mxGetData(out_keep)
    );

    mxFree(bbox_rm);

    if (rc != 0) {
        mxDestroyArray(out_freq);
        mxDestroyArray(out_keep);
        mexErrMsgIdAndTxt("dynamo:refine_peaks_mex:rust_error",
            "dynamo_refine_peaks returned error code %d.", rc);
    }

    plhs[0] = out_freq;
    if (nlhs > 1) {
        /* Convert uint8 keep to MATLAB logical for ergonomic downstream use */
        mxArray *out_keep_logical = mxCreateLogicalMatrix((mwSize)n, 1);
        const uint8_t *src = (const uint8_t *)mxGetData(out_keep);
        mxLogical *dst = mxGetLogicals(out_keep_logical);
        for (size_t i = 0; i < n; ++i) dst[i] = src[i] != 0;
        mxDestroyArray(out_keep);
        plhs[1] = out_keep_logical;
    } else {
        mxDestroyArray(out_keep);
    }
}
