function [zscored, mu, sigma] = nanzscore(data)

if any(isnan(data))
    mu = nanmean(data(:));
    sigma = nanstd(data(:));
    zscored = (data(:)-mu)./sigma(:);
else
    [zscored, mu, sigma] = zscore(data(:));
end

end

