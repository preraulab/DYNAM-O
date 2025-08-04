function [zscored, mu, sigma] = nanzscore(data, varargin)
inds = ~isnan(data);
[zscored, mu, sigma] = zscore(data(inds),varargin{:});

% %NANZSCORE compute zscores ignoring nans
% if any(isnan(data))
%     mu = mean(data,'all','omitnan');
%     sigma = std(data,0,'all','omitnan');
%     zscored = (data-mu)./sigma;
% else
%     [zscored, mu, sigma] = zscore(data(:));
% end

end

