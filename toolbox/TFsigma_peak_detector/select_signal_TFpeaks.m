function [ signal_idx, fig_compare ] = select_signal_TFpeaks(tpeak_properties, plot_on)
%SELECT_SIGNAL_TFPEAKS  Identify TF peak signals using K-means clustering on prominence and morphological features
%
%   Usage:
%       [signal_idx, fig_compare] = select_signal_TFpeaks(tpeak_properties, plot_on)
%
%   Inputs:
%       tpeak_properties: struct - TF peak properties with fields:
%                           .proms:                [1xP] double - peak prominences
%                           .durations:            [1xP] double - peak durations (s)
%                           .central_frequencies:  [1xP] double - peak center frequencies (Hz)
%                           .bandwidths:           [1xP] double - peak bandwidths (Hz)
%       plot_on:          logical - display clustering histograms (default: false)
%
%   Outputs:
%       signal_idx:  [1xP] logical - true for peaks classified as signal TF peaks
%       fig_compare: figure handle - histogram comparison figure ([] if plot_on is false)
%
%   Notes:
%       Uses K-means clustering (3 clusters) independently on 5 feature dimensions and then
%       combines the boolean cluster memberships to separate signal from noise peaks.
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
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
