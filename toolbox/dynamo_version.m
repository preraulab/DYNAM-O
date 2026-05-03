function v = dynamo_version()
%DYNAMO_VERSION  Return the DYNAM-O release version string.
%
%   This constant is what gets recorded in run-log JSONL entries and is
%   what a compiled standalone reports. Plain MATLAB code on the source
%   tree may also fall back to `git rev-parse --short HEAD` for a
%   develop-tree build identifier (see DYNAMORunLogger.detectCodeVersion),
%   but this constant always wins when present.
%
%   Bump this on release.

    v = '1.0.0';
end
