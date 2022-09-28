function [zscored, mu, sigma] = nanzscore(data)
%NANZSCORE compute zscores ignoring nans
if any(isnan(data))
    mu = nanmean(data(:));
    sigma = nanstd(data(:));
    zscored = (data(:)-mu)./sigma(:);
else
    [zscored, mu, sigma] = zscore(data(:));
end

end

