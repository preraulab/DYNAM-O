"""Thin wrapper around matlab.engine.connect_matlab for ad-hoc testing.

Usage (from DYNAMO_dev/.venv-matlab's Python):
    import matlab_bridge as mb
    out = mb.run("height(sortrows(magic(5)))")
    stats = mb.run_script("runDYNAMO_mex_test.m")

Prerequisite: in MATLAB, run `matlab.engine.shareEngine` once.
"""
from __future__ import annotations

import io
import sys
from typing import Any

import matlab.engine


_engine: matlab.engine.MatlabEngine | None = None


def _get() -> matlab.engine.MatlabEngine:
    global _engine
    if _engine is None:
        names = matlab.engine.find_matlab()
        if not names:
            sys.exit(
                "No shared MATLAB session. In MATLAB, run:\n"
                "    matlab.engine.shareEngine\n"
                "then retry."
            )
        _engine = matlab.engine.connect_matlab(names[0])
    return _engine


def run(cmd: str, capture_output: bool = True) -> Any:
    """Eval a MATLAB expression; return result. Captures stdout by default."""
    m = _get()
    if capture_output:
        buf = io.StringIO()
        try:
            result = m.eval(cmd, nargout=1, stdout=buf, stderr=buf)
        except matlab.engine.MatlabExecutionError as e:
            print(buf.getvalue(), end="")
            raise
        out = buf.getvalue()
        if out.strip():
            print(out, end="")
        return result
    return m.eval(cmd, nargout=0)


def run_void(cmd: str) -> None:
    """Run a MATLAB statement with no return value."""
    m = _get()
    buf = io.StringIO()
    try:
        m.eval(cmd, nargout=0, stdout=buf, stderr=buf)
    except matlab.engine.MatlabExecutionError:
        print(buf.getvalue(), end="")
        raise
    out = buf.getvalue()
    if out.strip():
        print(out, end="")


def cd(path: str) -> None:
    _get().cd(path, nargout=0)


def addpath(path: str) -> None:
    _get().addpath(path, nargout=0)


def get_workspace_var(name: str) -> Any:
    """Fetch a variable from the base workspace."""
    return _get().workspace[name]


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", nargs="+", help="MATLAB command(s) to run")
    args = ap.parse_args()
    # Commands that return nothing useful; treat as void.
    VOID_PREFIXES = ("addpath ", "addpath(", "rmpath ", "cd ", "cd(", "clear ")
    for c in args.cmd:
        print(f">> {c}")
        is_void = any(c.strip().startswith(p) for p in VOID_PREFIXES) or c.strip().endswith(";")
        if is_void:
            run_void(c)
        else:
            r = run(c)
            if r is not None and r != "":
                print(r)
