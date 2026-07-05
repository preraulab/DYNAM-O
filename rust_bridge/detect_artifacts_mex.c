/*
 * detect_artifacts_mex.c — MATLAB bridge to dynamo_rs::dynamo_detect_artifacts
 *
 * Signature from MATLAB:
 *     mask = detect_artifacts_mex(data, Fs, opts)
 *
 *     data   : Nx1 double  (raw single-channel time series)
 *     Fs     : scalar double
 *     opts   : struct with fields (all optional; defaults match
 *              ArtifactOpts::default in artifacts.rs):
 *                hf_pass            (default 35.0)
 *                hf_crit            (default 5.5)
 *                bb_pass            (default 0.1)
 *                bb_crit            (default 5.5)
 *                hf_detrend         (default true)
 *                bb_detrend         (default true)
 *                smooth_duration    (default 2.0)
 *                detrend_duration   (default 300.0)
 *                buffer_duration    (default 0.0)
 *                zscore_method      'robust' (default) | 'standard'
 *
 *     mask   : Nx1 logical (true = artifact)
 *
 * Excludes the slope-test branch (matches MATLAB
 * `detect_artifacts(..., 'slope_test', false)`). The .m wrapper ORs the
 * slope-test mask in afterwards if slope_test=true.
 */

#include "mex.h"
#include "dynamo_rs.h"

#include <ctype.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static double dfield(const mxArray *s, const char *name, double def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL || mxGetNumberOfElements(f) == 0) return def;
    if (!mxIsDouble(f) && !mxIsLogical(f) && !mxIsNumeric(f)) {
        mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:badField",
            "opts.%s must be numeric/logical scalar.", name);
    }
    return mxGetScalar(f);
}
static uint8_t bfield(const mxArray *s, const char *name, bool def) {
    mxArray *f = mxGetField(s, 0, name);
    if (f == NULL || mxGetNumberOfElements(f) == 0) return def ? 1u : 0u;
    return mxGetScalar(f) != 0.0 ? 1u : 0u;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    if (nrhs < 2 || nrhs > 3) {
        mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:nrhs",
            "Need data, Fs[, opts].");
    }
    if (nlhs > 1) {
        mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:nlhs",
            "At most 1 output: mask.");
    }
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0])) {
        mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:badInput",
            "data must be real double.");
    }
    if (!mxIsDouble(prhs[1]) || mxGetNumberOfElements(prhs[1]) != 1) {
        mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:badInput",
            "Fs must be a real-double scalar.");
    }

    size_t n  = mxGetNumberOfElements(prhs[0]);
    double fs = mxGetScalar(prhs[1]);

    struct ArtifactOptsFFI opts;
    opts.hf_pass          = 35.0;
    opts.hf_crit          = 5.5;
    opts.bb_pass          = 0.1;
    opts.bb_crit          = 5.5;
    opts.hf_detrend       = 1u;
    opts.bb_detrend       = 1u;
    opts.smooth_duration  = 2.0;
    opts.detrend_duration = 300.0;
    opts.buffer_duration  = 0.0;
    opts.zscore_method    = 0u;  /* Robust */

    if (nrhs == 3 && !mxIsEmpty(prhs[2])) {
        if (!mxIsStruct(prhs[2])) {
            mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:badInput",
                "opts must be a struct.");
        }
        const mxArray *s = prhs[2];
        opts.hf_pass          = dfield(s, "hf_pass",          opts.hf_pass);
        opts.hf_crit          = dfield(s, "hf_crit",          opts.hf_crit);
        opts.bb_pass          = dfield(s, "bb_pass",          opts.bb_pass);
        opts.bb_crit          = dfield(s, "bb_crit",          opts.bb_crit);
        opts.hf_detrend       = bfield(s, "hf_detrend",       true);
        opts.bb_detrend       = bfield(s, "bb_detrend",       true);
        opts.smooth_duration  = dfield(s, "smooth_duration",  opts.smooth_duration);
        opts.detrend_duration = dfield(s, "detrend_duration", opts.detrend_duration);
        opts.buffer_duration  = dfield(s, "buffer_duration",  opts.buffer_duration);

        mxArray *zm = mxGetField(s, 0, "zscore_method");
        if (zm != NULL && !mxIsEmpty(zm)) {
            if (!mxIsChar(zm)) {
                mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:badField",
                    "opts.zscore_method must be 'robust' or 'standard'.");
            }
            char buf[32]; mxGetString(zm, buf, sizeof(buf));
            for (int i = 0; buf[i]; ++i) buf[i] = (char)tolower((unsigned char)buf[i]);
            if (strcmp(buf, "robust") == 0)        opts.zscore_method = 0u;
            else if (strcmp(buf, "standard") == 0) opts.zscore_method = 1u;
            else mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:badField",
                    "opts.zscore_method must be 'robust' or 'standard'.");
        }
    }

    /* Scratch u8 buffer; we'll convert to logical for output. */
    uint8_t *mask_u8 = (uint8_t *)mxMalloc(n);

    int rc = dynamo_detect_artifacts(mxGetPr(prhs[0]), n, fs, &opts, mask_u8);
    if (rc != 0) {
        mxFree(mask_u8);
        mexErrMsgIdAndTxt("dynamo:detect_artifacts_mex:rust_error",
            "dynamo_detect_artifacts returned error code %d.", rc);
    }

    mxArray *out = mxCreateLogicalMatrix((mwSize)n, 1);
    mxLogical *dst = mxGetLogicals(out);
    for (size_t i = 0; i < n; ++i) dst[i] = mask_u8[i] != 0u;
    mxFree(mask_u8);

    plhs[0] = out;
}
