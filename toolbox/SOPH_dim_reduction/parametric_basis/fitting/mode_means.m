function [xmeans, ymeans] = mode_means(fitobj, xparam, yparam)
%MODE_MEANS  Extract the mean parameter values for each mode from a fitted model
%
%   Usage:
%       [xmeans, ymeans] = mode_means(fitobj, xparam, yparam)
%
%   Input:
%       fitobj: sfit object - fitted model containing mode coefficients -- required
%       xparam: char - coefficient name prefix for x-axis means (e.g., 'pmean') -- required
%       yparam: char - coefficient name prefix for y-axis means (e.g., 'fmean') -- required
%
%   Output:
%       xmeans: [1xN] double - x-axis mean values for each mode
%       ymeans: [1xN] double - y-axis mean values for each mode
%
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%% ********************************************************************
cvals = coeffvalues(fitobj);
xmeans = cvals(cellfun(@(x)~isempty(x),strfind(coeffnames(fitobj),xparam)));
ymeans = cvals(cellfun(@(x)~isempty(x),strfind(coeffnames(fitobj),yparam)));
