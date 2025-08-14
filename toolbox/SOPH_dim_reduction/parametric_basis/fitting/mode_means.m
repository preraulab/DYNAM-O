function [xmeans, ymeans] = mode_means(fitobj, xparam, yparam)
cvals = coeffvalues(fitobj);
xmeans = cvals(cellfun(@(x)~isempty(x),strfind(coeffnames(fitobj),xparam)));
ymeans = cvals(cellfun(@(x)~isempty(x),strfind(coeffnames(fitobj),yparam)));
