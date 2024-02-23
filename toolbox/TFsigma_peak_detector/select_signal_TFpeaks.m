function [ signal_idx, fig_compare ] = select_signal_TFpeaks(tpeak_properties, plot_on)
% A new way of identifying TF peak signals using Kmeans clustering on
% bandwith and duration dimensions and then joining booleans

if nargin < 2
    plot_on = false;
end

if ~plot_on
    fig_compare = [];
end

%% Visualization of raw histograms
X = [log(tpeak_properties.proms), log(tpeak_properties.proms.*tpeak_properties.durations.*tpeak_properties.bandwidths),...
    tpeak_properties.durations, tpeak_properties.central_frequencies, tpeak_properties.bandwidths];
labels = {'logProm', 'logVolm', 'Duration', 'Freq', 'Bandwidth'};

if plot_on
    fig_compare = figure;
    ax = figdesign(3,5, 'margin', [.05 .05 .05 .05 .05]);
    set(fig_compare, 'Position', [1 3 20 10])
    axis tight
    
    bin_edges = cell(1,5);
    
    % generate the histograms
    for pp = 1:5
        axes(ax(pp))
        h = histogram(X(:,pp));
        bin_edges{pp} = h.BinEdges;
        title(labels{pp})
        set(gca, 'FontSize', 16)
    end
end

%% Kmeans on each dimension
idx_mat = [];
for pp = 1:5
    current_signal = X(:,pp);
    num_clusters = 3;
    if pp == 3 % Duration prior at [0;1]
        idx = kmeans(current_signal, num_clusters, 'Start', [0;0.3;1]);
    elseif pp == 5 % Bandwidth prior at [0.5;2;3.5]
        idx = kmeans(current_signal, num_clusters, 'Start', [0.5;2;3.5]);
    else
        num_clusters = 2;
        idx = kmeans(current_signal, num_clusters);
    end

    % we will label the indices such that the right most cluster
    % will have index 1, and so on.
    mean_value = zeros(1, num_clusters);
    for jj = 1:num_clusters
        mean_value(jj) = nanmean(current_signal(idx==jj));
    end
    clustering_idx = idx;
    [~, clustering_order] = maxk(mean_value, num_clusters); 
    new_idx = zeros(size(idx));
    for jj = 1:num_clusters
        new_idx(idx == clustering_order(jj)) = jj;
    end
    idx_mat(:,pp) = new_idx;
    
    if plot_on
        % visualize the kmeans results
        axes(ax(pp+5))
        hold on
        for jj = 1:num_clusters
            histogram(current_signal(new_idx==jj), bin_edges{pp});
        end
        title([labels{pp}, ' kmeans'])
        set(gca, 'FontSize', 16)
    end
end

%% Combine bandwidth and duration dimensions to identify events
signal_idx = idx_mat(:,3)==1 & idx_mat(:,5)==1;

if plot_on
    for pp = 1:5
        % visualize the kmeans results
        axes(ax(pp+10))
        histogram(X(signal_idx==1, pp), bin_edges{pp});
        hold on
%         histogram(X(signal_idx==0, pp), bin_edges{pp});
        title([labels{pp}, ' (signals)'])
        set(gca, 'FontSize', 16)
        linkaxes([ax(pp), ax(pp+5), ax(pp+10)], 'xy')
    end
end

disp(['Total #signal events: ', num2str(sum(signal_idx==1))])

end
