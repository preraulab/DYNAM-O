function v = DYNAMO_TOOLBOX_VERSION()
%DYNAMO_TOOLBOX_VERSION  Semantic version of the DYNAM-O MATLAB toolbox
%
%   Usage:
%       v = DYNAMO_TOOLBOX_VERSION()
%
%   Inputs:
%       none
%
%   Outputs:
%       v : char - the toolbox semver, e.g. '1.0.0'
%
%   Notes:
%       Single source of truth for the '<semver>' part of the DYNAM-O
%       provenance grammar '<semver>+<sha12>[.dirty]' that dynamo_version
%       composes. Bump this constant on releases; the sha half is derived
%       from git at call time.
%
%   Example:
%       v = DYNAMO_TOOLBOX_VERSION();   % '1.0.0'
%
%   See also: dynamo_version, dynamo_stamp
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

v = '1.0.0';
end
