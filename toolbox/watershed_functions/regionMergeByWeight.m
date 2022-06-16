function [rgn, Lborders] = regionMergeByWeight(data,rgn,rgn_lbls,Lborders,amatr,merge_thresh,max_merges,merge_rule,f_verb,verb_pref,f_disp)
%regionMergeByWeight takes the labeled image, borders, and adjacencies output
% from peaksWShed and merges the regions according to the desired rule. The
% default rule is designed to form large, complete peaks. It calls
% regionWeightedEdges and regionMerge.
%
% INPUTS:
%   data         -- 2D matrix of image data. defaults to peaks(100).
%   rgn          -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   rgn_lbls     -- vector of region labels.
%   Lborders     -- 1D cell array of vector lists of linear idx of border pixels for each region
%   amatr        -- two-column matrix of region adjacencies.
%                   each row contains region lables of two adjacent regions.
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
%   rgn, Lborders -- versions of inputs after merger
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
% Created on: 20170907 -- forked from version in wshed1, the code of this
%                         function was consolidated from peaks_wshed_excerpt.m
% Modified: 20190215 -- cleaned up for toolbox
%           20170930 -- To handle case of single region
%

%*************************
% Handle variable inputs *
%*************************
if nargin < 11
    f_disp = [];
end
if nargin < 10
    verb_pref = [];
end
if nargin < 9
    f_verb = [];
end
if nargin < 8
    merge_rule = [];
end
if nargin < 7
    max_merges = [];
end
if nargin < 6
    merge_thresh = [];
end
if nargin < 5
    amatr = [];
end
if nargin < 4
    Lborders = [];
end
if nargin < 3
    rgn_lbls = [];
end
if nargin < 2
    rgn = [];
end
if nargin < 1
    data = [];
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
if isempty(merge_rule)
    merge_rule = 'absolute';
end
if isempty(max_merges)
    max_merges = inf;
end
if isempty(merge_thresh)
    merge_thresh = 8;
end

%*************************
% Check necessary inputs *
%*************************
if isempty(data) && isempty(rgn) && isempty(rgn_lbls) && isempty(Lborders) && isempty(amatr)
    [rgn, rgn_lbls, Lborders, amatr, data] = peaksWShed;
    f_valid_inputs = true;
elseif ~isempty(data) && ~isempty(rgn) && ~isempty(rgn_lbls) && ~isempty(Lborders) && ~isempty(amatr)
    f_valid_inputs = true;
elseif isempty(amatr) && ~isempty(data) && ~isempty(rgn) && ~isempty(rgn_lbls) && ~isempty(Lborders)
    f_valid_inputs = false;
    disp('Caution: amatr is empty, possibly indicative of a single region input to merge.');
else
    f_valid_inputs = false;
    disp('WARNING: data, rgn, Lborders, rgn_lbls, or amatr were not provided to regionMergeByWeight. Returning original regions.');
end

%*************************
% Check adjacency matrix *
%*************************
if f_valid_inputs
    if size(amatr,2)==3
        % Extract initial weights if provided in amatr
        if f_verb > 0
            disp([verb_pref 'Adjacency matrix already has edge weights. Extracting initial weights...']);
        end
        ematr = amatr;
        % e_wts = amatr(:,3);
        % amatr = amatr(:,1:2);
    elseif size(amatr,2)==2
        % Compute initial weights if not provided
        if f_verb > 0
            disp([verb_pref 'Computing initial edge weights...']);
            ttic = tic;
        end
        e_wts = regionWeightedEdges(rgn,data,rgn_lbls,Lborders,amatr,merge_rule,f_verb-1,['  ' verb_pref]);
        if f_verb > 0
            disp([verb_pref '  Initial weighting took ' num2str(toc(ttic)) ' sec.']);
        end
        ematr = [amatr e_wts];
    else
        % The adjacency matrix of inappropiate shape. This is an erroneous condition.
        ematr = [];
        f_valid_inputs = false;
        disp(['WARNING: adjacency matrix (' num2str(size(amatr,1)) ' x ' ...
            num2str(size(amatr,2)) ') has too few or too many columns. Returning original regions.' ]);
        
    end
end

%****************
% Merge regions *
%****************
if f_valid_inputs
    % Plot original image data
    if f_disp
        figure('units','normalized','position',[0.2299   -0.1778    0.9896    0.4789]);
        ax(1) = subplot(1,3,1);
        ax(2) = subplot(1,3,2);
        ax(3) = subplot(1,3,3);
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
    num_rgns = 0;
    for ii = 1:length(rgn)
        if ~isempty(rgn{ii})
            num_rgns = num_rgns + 1;
        end
    end
    [max_wt,max_idx] = max(ematr(:,3));
    num_merges = 0;
    if f_verb > 0
        disp([verb_pref 'Merging regions...']);
        ttic = tic;
        if f_verb > 1
            disp([verb_pref '  Size of edge matrix: ' num2str(size(ematr,1)) '. Maximum weight: ' num2str(max_wt) '.']);
        end
    end
    while ~isempty(ematr) && max_wt > merge_thresh && num_merges < max_merges && num_rgns > 1
        % Determine regions to merge
        mrg_to = ematr(max_idx(1),1);
        mrg_from = ematr(max_idx(1),2);
        
        % Merge regions
        [rgn, Lborders, ematr, pick_update] = regionMerge(rgn,mrg_to,mrg_from,rgn_lbls,Lborders,ematr);
        
        % Update edge weights
        if ~isempty(find(pick_update,1))
            e_wts = regionWeightedEdges(rgn,data,rgn_lbls,Lborders,ematr(pick_update,1:2),merge_rule,f_verb-1,['  ' verb_pref]);
            ematr(pick_update,3) = e_wts;
        end
        
        % Find new maximum weight and its index
        if ~isempty(ematr)
            [max_wt,max_idx] = max(ematr(:,3));
        else
            max_wt = 0;
        end
        num_merges = num_merges + 1;
        num_rgns = num_rgns - 1;
        
        % Update region plot
        if f_disp && mod(num_merges,100)==1
            % Plot data with boundaries
            tmp_Ldata = cell2Ldata(rgn,size(data),Lborders);
            tmp_data = data;
            tmp_data(tmp_Ldata==0)=-inf;
            imagesc(ax(2),tmp_data);
            axis(ax(2),'xy');
            climscale(ax(2));
            cm = jet(1024);
            cm(1,:)=[1 0 1];
            colormap(ax(2),cm);
            title(ax(2),['Current weight merged: ' num2str(max_wt)]);
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
            title(ax(3),['Current weight merged: ' num2str(max_wt)]);
            drawnow;
        end
        
        if f_verb > 1
            disp([verb_pref '  Size of edge matrix: ' num2str(size(ematr,1)) '. Maximum weight: ' num2str(max_wt) '.']);
        end
        
    end
    
    if f_verb > 0
        disp([verb_pref '  Full merging took ' num2str(toc(ttic)) ' sec, ' num2str(num_merges) ' merges.']);
        if isempty(ematr) || num_rgns <= 1
            disp([verb_pref 'single region encountered in merge']);
        end
    end
    
    if f_disp
        % Plot data with boundaries
        tmp_Ldata = cell2Ldata(rgn,size(data),Lborders);
        tmp_data = data;
        tmp_data(tmp_Ldata==0) = -inf;
        imagesc(ax(2),tmp_data);
        axis(ax(2),'xy');
        climscale(ax(2));
        cm = jet(1024);
        cm(1,:)=[1 0 1];
        colormap(ax(2),cm);
        title(ax(2),['Current weight merged: ' num2str(max_wt)]);
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
        title(ax(3),['Current weight merged: ' num2str(max_wt)]);
    end
    
end

end

