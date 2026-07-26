#!/usr/bin/env bash
# Run benchmark_runDYNAMO in headless MATLAB (no Qt/CEF GUI, no waitbar,
# no font rendering). Dodges the MATLAB R2025b + macOS 26.3.1 Qt
# fontations_ffi SIGSEGV that takes down the desktop session whenever
# CEF's MainMessageLoopExternalPump timer fires during a long run.
#
# Usage (from this dir or anywhere):
#   ./run_benchmark.sh                          # both backends, night fixture
#   ./run_benchmark.sh segment                  # override fixture
#   ./run_benchmark.sh night rust               # skip matlab backend
#
# Auto-detects matlab on PATH or falls back to /Applications/MATLAB*.app
# on macOS. The JSON is written without changing the Git index or history.
# Exits non-zero if MATLAB can't be launched.

set -euo pipefail

FIXTURE="${1:-night}"
BACKENDS_ARG="${2:-both}"
case "$BACKENDS_ARG" in
    rust)   BACKENDS="{'rust'}" ;;
    matlab) BACKENDS="{'matlab'}" ;;
    both|*) BACKENDS="{'rust','matlab'}" ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_ROOT="$(dirname "$HERE")"

# Locate matlab. Search PATH first, then standard install locations per OS.
MATLAB_BIN=""
if command -v matlab >/dev/null 2>&1; then
    MATLAB_BIN="$(command -v matlab)"
elif [[ "$(uname)" == "Darwin" ]]; then
    # macOS — newest version wins on tie-break.
    MATLAB_BIN="$(ls -d /Applications/MATLAB_R*.app 2>/dev/null | sort -r | head -1)/bin/matlab"
elif [[ "$(uname)" == "Linux" ]]; then
    # Linux — MathWorks default, plus /opt/ for unattended installs.
    for globbed in /usr/local/MATLAB/R*/bin/matlab /opt/MATLAB/R*/bin/matlab; do
        for m in $globbed; do
            [[ -x "$m" ]] && MATLAB_BIN="$m" && break 2
        done
    done
fi
if [[ ! -x "$MATLAB_BIN" ]]; then
    echo "error: matlab not found on PATH, /Applications/MATLAB_R*.app, /usr/local/MATLAB/R*, or /opt/MATLAB/R*" >&2
    exit 1
fi
echo "MATLAB: $MATLAB_BIN"
echo "Fixture: $FIXTURE"
echo "Backends: $BACKENDS"

# -batch runs the statement and exits — no desktop, no Qt, no CEF,
# no font rendering. -nodisplay is redundant but belt-and-braces.
exec "$MATLAB_BIN" -nodisplay -batch "\
    addpath(genpath('$DEV_ROOT')); \
    cd('$HERE'); \
    benchmark_runDYNAMO('fixture', '$FIXTURE', 'backends', $BACKENDS, 'push', 'no'); \
    exit"
