/*
 * dynamo_version_mex.c — MATLAB bridge to dynamo_rs::dynamo_version
 *
 * Signature from MATLAB:
 *     [version, abi] = dynamo_version_mex()
 *
 *     version : char row vector - kernel build identity in the DYNAM-O
 *               provenance grammar '<semver>+<sha12>[.dirty]' (or
 *               '<semver>+unknown' for a non-git build)
 *     abi     : scalar double   - DYNAMO_C_ABI_VERSION of the loaded
 *               library (additive-only contract)
 *
 * This reports the identity of the dynamo_rs library actually LOADED by
 * this process — unlike rust_bridge/build_manifest.json, which records
 * what was on disk at build time. dynamo_kernel_version.m prefers this
 * gateway and falls back to the manifest when the gateway is absent.
 *
 * The returned string is a 'static inside the library; we copy it into a
 * MATLAB char array, so nothing is freed here.
 */

#include "mex.h"
#include "dynamo_rs.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    (void)prhs;
    if (nrhs != 0) {
        mexErrMsgIdAndTxt("dynamo:dynamo_version_mex:nrhs",
            "dynamo_version_mex takes no inputs.");
    }
    if (nlhs > 2) {
        mexErrMsgIdAndTxt("dynamo:dynamo_version_mex:nlhs",
            "At most 2 outputs: version, abi.");
    }

    const char *v = dynamo_version();
    plhs[0] = mxCreateString(v ? v : "unknown");
    if (nlhs > 1) {
        plhs[1] = mxCreateDoubleScalar((double)dynamo_c_abi_version());
    }
}
