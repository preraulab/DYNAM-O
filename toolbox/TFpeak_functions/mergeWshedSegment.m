function [regions, borders] = mergeWshedSegment(data,regions,region_lbls,borders,adj_list,merge_thresh,max_merges,merge_rule,f_verb,verb_pref,f_disp)
% MERGEWSHEDSEGMENT takes the labeled image, borders, and adjacencies output
% from peaksWShed and merges the regions according to the desired rule. The
% default rule is designed to form large, complete peaks. It calls
% computeMergeWeights and mergeRegion.
%
% Usage:
%   [regions, borders] = mergeWshedSegment(data,regions,region_lbls,borders,adj_list,merge_thresh,max_merges,merge_rule,f_verb,verb_pref,f_disp)
%
% INPUTS:
%   data         -- 2D matrix of image data. defaults to peaks(100).
%   regions          -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   region_lbls     -- vector of region labels.
%   borders     -- 1D cell array of vector lists of linear idx of border pixels for each region
%   adj_list        -- two-column matrix of region adjacencies.
%                   each row contains region labels of two adjacent regions.
%   merge_thresh -- threshold weight value for when to stop merge rule. default 8.
%   max_merges   -- maximum number of merges to perform. default inf.
%   merge_rule   -- default = absolute
%   f_verb       -- number indicating depth of output text statements of progress.
%                   0 - no output. 1 - output current function level.
%                   >1 - output at subfunction levels. defaults to 0, unless using defaul data.
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%   f_disp       -- flag indicator of whether to plot.
%                   defaults to 0, unless using default data.
%
% OUTPUTS:
%   region, borders -- versions of inputs after merger
%
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

%*************************
% Handle variable inputs *
%*************************
if nargin < 1 || isempty(data)
    error('Data must be specified')
end
if nargin < 2
    regions = [];
end
if nargin < 3
    region_lbls = [];
end
if nargin < 4
    borders = [];
end
if nargin < 5
    adj_list = [];
end
if nargin < 6
    merge_thresh = [];
end
if nargin < 7
    max_merges = [];
end
if nargin < 8
    merge_rule = [];
end
if nargin < 9
    f_verb = [];
end
if nargin < 10
    verb_pref = [];
end
if nargin < 11
    f_disp = [];
end

%************************
% Set default arguments *
%************************
if isempty(f_disp)
    f_disp = 0;
end
if isempty(verb_pref)
    verb_pref = '';
end
if isempty(f_verb)
    f_verb = 0;
end

%NOT USED
if isempty(merge_rule)
    merge_rule = 'default';
end

if isempty(max_merges)
    max_merges = inf;
end
if isempty(merge_thresh)
    merge_thresh = 8;
end

%*************************
% Check adjacency matrix *
%*************************
if size(adj_list,2)==3
    % Extract initial weights if provided in amatr
    if f_verb > 0
        disp([verb_pref 'Adjacency matrix already has edge weights. Extracting initial weights...']);
    end
    ematr = adj_list;
elseif size(adj_list,2)==2
    % Compute initial weights if not provided
    if f_verb > 0
        disp([verb_pref 'Computing initial edge weights...']);
        ttic = tic;
    end
    e_wts = computeMergeWeights(regions,data,region_lbls,borders,adj_list,merge_rule,f_verb-1,['  ' verb_pref]);
    if f_verb > 0
        disp([verb_pref '  Initial weighting took ' num2str(toc(ttic)) ' sec.']);
    end
    ematr = [adj_list e_wts];
else
    % The adjacency matrix of inappropiate shape. This is an erroneous condition.
    ematr = [];
    % f_valid_inputs = false;
    disp(['WARNING: adjacency matrix (' num2str(size(adj_list,1)) ' x ' ...
        num2str(size(adj_list,2)) ') has too few or too many columns. Returning original regions.' ]);

end

%****************
% Merge regions *
%****************
% Plot original image data
if f_disp
    figure('units','normalized','position',[1.1020 0.1819 0.6867 0.6333]);
    ax(1) = subplot(2,2,1);
    ax(2) = subplot(2,2,2);
    ax(3) = subplot(2,2,3);
    ax(4) = subplot(2,2,4);
    if min(data(:)) < 0
        imagesc(ax(1),data);
    else
        imagesc(ax(1),pow2db(data));
    end
    axis(ax(1),'xy');
    climscale(ax(1));
    colormap(ax(1),jet);
    title(ax(1),'Original Data Image');
end

% Determine number of regions and maximum edge weight
num_regions = length(regions);
if num_regions == 1
    return
end
[max_wt,max_idx] = max(ematr(:,3));

% Set dynamic merge_thresh if merge_thresh is nan
if isnan(merge_thresh)
    merge_thresh = prctile(ematr(:,3), 95);
end

num_merges = 0;
if f_verb > 0
    disp([verb_pref 'Merging regions...']);
    ttic = tic;
    if f_verb > 1
        disp([verb_pref '  Size of edge matrix: ' num2str(size(ematr,1)) '. Maximum weight: ' num2str(max_wt) '.']);
    end
end

%%
%********************
% MAIN MERGING LOOP *
%********************
while ~isempty(ematr) && max_wt > merge_thresh && num_merges < max_merges && num_regions > 1
    % Determine regions to merge
    mrg_to = ematr(max_idx(1),1);
    mrg_from = ematr(max_idx(1),2);

    % Merge regions
    [regions, borders, ematr, pick_update] = mergeRegions(regions,mrg_to,mrg_from,region_lbls,borders,ematr);

    % Update edge weights
    if ~isempty(find(pick_update,1))
        e_wts = computeMergeWeights(regions,data,region_lbls,borders,ematr(pick_update,1:2),merge_rule,f_verb-1,['  ' verb_pref]);
        ematr(pick_update,3) = e_wts;
    end

    % Find new maximum weight and its index
    if ~isempty(ematr)
        [max_wt,max_idx] = max(ematr(:,3));
    else
        max_wt = 0;
    end
    num_merges = num_merges + 1;
    num_regions = num_regions - 1;

    % Update region plot
    if f_disp && mod(num_merges,100)==1 % only plot every 100 merges
        % Plot data with boundaries
        tmp_Ldata = cell2Ldata(regions,size(data),borders);
        tmp_data = data;
        tmp_data(tmp_Ldata==0)=-inf;
        imagesc(ax(2),tmp_data);
        axis(ax(2),'xy');
        climscale(ax(2));
        cm = jet(1024);
        cm(1,:)=[1 0 1];
        colormap(ax(2),cm);
        title(ax(2),['Current weight merged: ' num2str(max_wt), ' (threhold: ' num2str(merge_thresh), ')']);
        % Plot regions
        RGB2 = label2rgb(tmp_Ldata, 'jet', 'c', 'shuffle');
        R = squeeze(RGB2(:,:,1));
        G = squeeze(RGB2(:,:,2));
        B = squeeze(RGB2(:,:,3));
        R(~tmp_Ldata) = 100;
        G(~tmp_Ldata) = 100;
        B(~tmp_Ldata) = 100;
        RGB2 = cat(3,R,G,B);
        imagesc(ax(3),RGB2);
        axis(ax(3),'xy');
        title(ax(3),['Current weight merged: ' num2str(max_wt), ' (threhold: ' num2str(merge_thresh), ')']);
        % Plot borders
        temp_B_data = zeros(size(data));
        for ii = 1:length(borders)
            ii_pixels = borders{ii};
            temp_B_data(ii_pixels)=ii;
            if ~isempty(borders{ii})
                temp_B_data(borders{ii}) = 0;
            end
        end
        RGB2 = label2rgb(temp_B_data, 'jet', 'c', 'shuffle');
        R = squeeze(RGB2(:,:,1));
        G = squeeze(RGB2(:,:,2));
        B = squeeze(RGB2(:,:,3));
        R(~tmp_Ldata) = 100;
        G(~tmp_Ldata) = 100;
        B(~tmp_Ldata) = 100;
        RGB2 = cat(3,R,G,B);
        imagesc(ax(4),RGB2);
        axis(ax(4),'xy');
        title(ax(4), 'Borders of merged regions');
        drawnow;
        pause(1)
    end

    if f_verb > 1
        disp([verb_pref '  Size of edge matrix: ' num2str(size(ematr,1)) '. Maximum weight: ' num2str(max_wt) '.']);
    end

end

% Checks to see if only one region found that fills the entire area,
% create a 1-pixel border around the entire region
if num_regions==1
    [region_size, region_ind] = max(cellfun(@numel,regions));
    if region_size==numel(data)
        temp_border = zeros(size(data));
        temp_border(1,:) = 1;
        temp_border(:,1) = 1;
        temp_border(end,:) = 1;
        temp_border(:,end) = 1;
        borders{region_ind} = find(temp_border==1);
    end
end

if f_verb > 0
    disp([verb_pref '  Full merging took ' num2str(toc(ttic)) ' sec, ' num2str(num_merges) ' merges.']);
    if isempty(ematr) || num_regions <= 1
        disp([verb_pref 'single region encountered in merge']);
    end
end

if f_disp
    % Plot data with boundaries
    tmp_Ldata = cell2Ldata(regions,size(data),borders);
    tmp_data = data;
    tmp_data(tmp_Ldata==0) = -inf;
    imagesc(ax(2),tmp_data);
    axis(ax(2),'xy');
    climscale(ax(2));
    cm = jet(1024);
    cm(1,:)=[1 0 1];
    colormap(ax(2),cm);
    title(ax(2),['Current weight merged: ' num2str(max_wt), ' (threhold: ' num2str(merge_thresh), ')']);
    % Plot regions
    RGB2 = label2rgb(tmp_Ldata, 'jet', 'c', 'shuffle');
    R = squeeze(RGB2(:,:,1));
    G = squeeze(RGB2(:,:,2));
    B = squeeze(RGB2(:,:,3));
    R(~tmp_Ldata) = 100;
    G(~tmp_Ldata) = 100;
    B(~tmp_Ldata) = 100;
    RGB2 = cat(3,R,G,B);
    imagesc(ax(3),RGB2);
    axis(ax(3),'xy');
    title(ax(3),['Current weight merged: ' num2str(max_wt), ' (threhold: ' num2str(merge_thresh), ')']);
    % Plot borders
    temp_B_data = zeros(size(data));
    for ii = 1:length(borders)
        ii_pixels = borders{ii};
        temp_B_data(ii_pixels)=ii;
        if ~isempty(borders{ii})
            temp_B_data(borders{ii}) = 0;
        end
    end
    RGB2 = label2rgb(temp_B_data, 'jet', 'c', 'shuffle');
    R = squeeze(RGB2(:,:,1));
    G = squeeze(RGB2(:,:,2));
    B = squeeze(RGB2(:,:,3));
    R(~tmp_Ldata) = 100;
    G(~tmp_Ldata) = 100;
    B(~tmp_Ldata) = 100;
    RGB2 = cat(3,R,G,B);
    imagesc(ax(4),RGB2);
    axis(ax(4),'xy');
    title(ax(4), 'Borders of merged regions');
end

% Remove dead regions
regions = regions(cellfun(@(x)~isempty(x),regions));
borders = borders(cellfun(@(x)~isempty(x),borders));
