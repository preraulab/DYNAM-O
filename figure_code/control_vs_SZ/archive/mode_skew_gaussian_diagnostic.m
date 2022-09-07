
%% Histograms
titles = {'amp','freq mean','freq var','pow alpha','pow location','pow scale', 'vol', 'sg mode' 'pow centroid' 'freq centroid' 'density centroid'};

for ii = 1:size(params,2)
    figure;
    histogram(squeeze(params(:,ii,:)), 100);
    title(titles{ii})
end

%outlier_px_inds = find(squeeze(params(1,4,:)) < -600)

%% Night1 vs Night2

for ii = 1:size(params,2)
    figure;
    n1 = squeeze(params(1,ii,night_out==1));
    n2 = squeeze(params(1,ii,night_out==2));
    plot(n1, n2, '.')
    title([titles{ii}, ' \rho=', num2str(corr(n1,n2,'rows','complete'))])
    xlabel('Night 1');
    ylabel('Night 2');
end



