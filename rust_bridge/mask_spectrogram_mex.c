/*
 * mask_spectrogram_mex.c — MATLAB bridge to dynamo_rs::mask::mask_spectrogram
 *
 * Drop-in replacement for MATLAB's maskSpectrogram. Uses pydynamo's
 * validated perimeter-aware Rust implementation (the same one that
 * produces the +0.4% night parity number documented in DYNAM-O_rs/README.md).
 *
 * Signature from MATLAB:
 *     masked = mask_spectrogram_mex(spect_2s, stimes_2s, labels_1s, stimes_1s)
 *
 *     spect_2s:   F x T2 double  (MATLAB column-major, pass-2 spectrogram)
 *     stimes_2s:  1 x T2 double
 *     labels_1s:  F x T1 int64   (label image from pass-1 extract_tfpeaks_mex)
 *     stimes_1s:  1 x T1 double
 *
 *     masked:     F x T2 double  (pass-2 masked, MATLAB column-major)
 *
 * Layout note: Rust expects row-major (F, T). MATLAB gives column-major (F, T).
 * Transpose-copy both spect_2s and labels_1s on input; transpose back on output.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <stdint.h>
#include <string.h>

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs != 4) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:nrhs",
            "4 inputs: spect_2s, stimes_2s, labels_1s, stimes_1s");
    }
    if (nlhs > 1) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:nlhs",
            "At most 1 output (masked spectrogram).");
    }
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0])) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:badInput",
            "spect_2s must be real double.");
    }
    if (!mxIsDouble(prhs[1]) || mxIsComplex(prhs[1])) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:badInput",
            "stimes_2s must be real double.");
    }
    if (!mxIsInt64(prhs[2])) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:badInput",
            "labels_1s must be int64.");
    }
    if (!mxIsDouble(prhs[3]) || mxIsComplex(prhs[3])) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:badInput",
            "stimes_1s must be real double.");
    }

    mwSize F  = mxGetM(prhs[0]);
    mwSize T2 = mxGetN(prhs[0]);
    mwSize T1 = mxGetN(prhs[2]);
    if (mxGetM(prhs[2]) != F) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:dims",
            "labels_1s rows (%d) must match spect_2s rows (%d).",
            (int)mxGetM(prhs[2]), (int)F);
    }
    if (mxGetNumberOfElements(prhs[1]) != T2) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:dims",
            "stimes_2s length (%d) != spect_2s cols (%d).",
            (int)mxGetNumberOfElements(prhs[1]), (int)T2);
    }
    if (mxGetNumberOfElements(prhs[3]) != T1) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:dims",
            "stimes_1s length (%d) != labels_1s cols (%d).",
            (int)mxGetNumberOfElements(prhs[3]), (int)T1);
    }

    /* Transpose spect_2s and labels_1s to row-major via mexCallMATLAB. */
    mxArray *spect_t = NULL;
    if (mexCallMATLAB(1, &spect_t, 1, (mxArray **)&prhs[0], "transpose") != 0) {
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:transpose",
            "Failed to transpose spect_2s.");
    }
    mxArray *lbl_t = NULL;
    if (mexCallMATLAB(1, &lbl_t, 1, (mxArray **)&prhs[2], "transpose") != 0) {
        mxDestroyArray(spect_t);
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:transpose",
            "Failed to transpose labels_1s.");
    }

    /* Caller-allocated output — we build transposed (T2 x F) then transpose back. */
    mxArray *out_t = mxCreateDoubleMatrix((mwSize)T2, (mwSize)F, mxREAL);
    int rc = dynamo_mask_spectrogram(
        mxGetPr(spect_t),
        mxGetPr(prhs[1]),
        (const int64_t *)mxGetData(lbl_t),
        mxGetPr(prhs[3]),
        (size_t)F, (size_t)T2, (size_t)T1,
        mxGetPr(out_t)
    );

    mxDestroyArray(spect_t);
    mxDestroyArray(lbl_t);

    if (rc != 0) {
        mxDestroyArray(out_t);
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:rust_error",
            "dynamo_mask_spectrogram returned error %d.", rc);
    }

    /* Transpose output (T2 x F row-major view = bytes) back to (F x T2)
     * MATLAB column-major: call transpose. */
    mxArray *masked = NULL;
    if (mexCallMATLAB(1, &masked, 1, &out_t, "transpose") != 0) {
        mxDestroyArray(out_t);
        mexErrMsgIdAndTxt("dynamo:mask_spectrogram_mex:transpose",
            "Failed to transpose output.");
    }
    mxDestroyArray(out_t);
    plhs[0] = masked;
}
