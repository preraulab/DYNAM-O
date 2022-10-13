function e_wts = computeMergeWeights(regions,data,region_lbls,region_bnds,adj_list,f_verb,verb_pref)
% COMPUTEMERGEWEIGHTS determines the weights of directed adjacencies between regions
% in a segmented 2D image. The weights are computed by edgeWeight, which is
% internalized for speed.
%
% Usage:
%    e_wts = computeMergeWeights(regions, data, region_lbls, region_bnds, adj_list, f_verb, verb_pref)
%
% INPUTS:
%   regions      -- a 1D cell array with each cell containing a vector of linear
%               indices of the pixels in the region.
%   data     -- the 2D image matrix from which the regions were identified.
%   region_lbls -- a vector, of same dimension as rgn, with labels for
%               corresponding regions.
%   region_bnds -- a 1D cell array, of same size as rgn, with each cell
%               containing the vector of linear indices of the boundary
%               pixels of the corresponding region.
%   adj_list    -- a two-column matrix of directed region adjacencies.
%               each row contains region lables of two adjacent regions.
%               the first column are "to regions", and the second column
%               are "from regions.
%
% OUTPUTS:
%   e_wts -- a vector storing the edge weights, one for each row of directed
%            adjacency in amatr.
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Authors: Patrick Stokes, Thomas Possidente, Michael Prerau
%

if nargin < 7
    verb_pref = [];
end
if nargin < 6
    f_verb = [];
end

if nargin < 5
    adj_list = [];
end
if nargin < 4
    region_bnds =[];
end
if nargin < 3
    region_lbls = [];
end
if nargin < 2
    data = [];
end
if nargin < 1
    regions = [];
end

if isempty(data) || isempty(regions) || isempty(region_lbls) || isempty(adj_list)
    disp('WARNING: insufficient inputs to regionWeightedEdges');
else
    e_wts = zeros(size(adj_list,1),1);

    if isempty(f_verb)
        f_verb = 0;
    else
        if isempty(verb_pref)
            verb_pref = '';
        end
    end
    if length(region_lbls) > 1
        if f_verb>0
            disp([verb_pref 'Weighting regions...']);
        end
        % For each adjacency, determine directed edge weight
        for ii = 1:length(e_wts)
            % Get "to region" of current adjacency
            rgn_lbl_ii = region_lbls==adj_list(ii,1); % logical indicating label index of "to region"
            rgn_ii = regions{rgn_lbl_ii}; % linear indices of pixels of "to region"

            % Get "from region" of current adjacency
            rgn_lbl_jj = region_lbls==adj_list(ii,2); % logical indicating label index of "from region"
            rgn_jj = regions{rgn_lbl_jj}; % linear indices of pixels of "from region"

            % Get boundaries of current regions
            if isempty(region_bnds)
                % Use data if boundaries not provided
                ldata_ii = zeros(size(data));
                ldata_ii(rgn_ii) = adj_list(ii,1);
                tmp_bnds = bwboundaries(ldata_ii>0,4,'holes');
                bnds_ii = [];
                for kk = 1:length(tmp_bnds)
                    bnds_ii = [bnds_ii; sub2ind(size(data),tmp_bnds{kk}(:,1),tmp_bnds{kk}(:,2))];
                end
                ldata_jj = zeros(size(data));
                ldata_jj(rgn_jj) = adj_list(ii,2);
                tmp_bnds = bwboundaries(ldata_jj>0,4,'holes');
                bnds_jj = [];
                for kk = 1:length(tmp_bnds)
                    bnds_jj = [bnds_jj; sub2ind(size(data),tmp_bnds{kk}(:,1),tmp_bnds{kk}(:,2))];
                end
            else
                bnds_ii = region_bnds{rgn_lbl_ii};
                bnds_jj = region_bnds{rgn_lbl_jj};
            end

            % Compute current edge weight
            e_wts(ii)  = edgeWeightEqual(rgn_ii,bnds_ii,rgn_jj,bnds_jj,data);
        end
    else
        if f_verb>0
            disp([verb_pref 'Single region encountered in weighting.']);
        end
    end
end
end

function e = edgeWeightEqual(rgn_ii,bnds_ii,rgn_jj,bnds_jj,data)
% %Add switch case to add new merge rules
% c = max(data(adj_bnd)) - min(data(bnds_ii));
% d = max(data(rgn_jj)) - max(data(adj_bnd));
% e = c - d;
%
% Take max of weight(ii,jj) and weight(jj,ii)

% fastest version to get intersection of "to region" boundary with "from region"
adj_bnds = bnds_ii(ismember(bnds_ii,bnds_jj));

%Max data value of the adjacent boundary pixels
max_adj = max(data(adj_bnds));

%Get the min boundary values
min_bnds_ii = min(data(bnds_ii));
min_bnds_jj = min(data(bnds_jj));

%Get the max data values
max_rgn_ii = max(data(rgn_jj));
max_rgn_jj = max(data(rgn_ii));

%Compute the weights for each
eii = 2*max_adj - min_bnds_ii - max_rgn_jj;
ejj = 2*max_adj - min_bnds_jj - max_rgn_ii;

%Take the max weight
e = max(eii,ejj);
end
