function e_wts = computeMergeWeights(rgn,data,rgn_lbls,rgn_bnds,amatr,merge_rule,f_verb,verb_pref,lbl_map)
% COMPUTEMERGEWEIGHTS determines the weights of directed adjacencies between regions
% in a segmented 2D image. The weights are computed by edgeWeight, which is
% internalized for speed.
%
% Usage:
%    e_wts = computeMergeWeights(rgn,data,rgn_lbls,rgn_bnds,amatr,merge_rule,f_verb,verb_pref,lbl_map)
%
% Optional lbl_map: containers.Map mapping region label -> slot index.
% When provided, replaces the per-edge O(R) `rgn_lbls==amatr(ii,X)` linear
% scans with O(1) lookups. mergeWshedSegment already builds this map; pass
% it here to avoid rebuilding label-to-slot indices inside the hot loop.
%
%   Inputs:
%   rgn      -- a 1D cell array with each cell containing a vector of linear
%               indices of the pixels in the region.
%   data     -- the 2D image matrix from which the regions were identified.
%   rgn_lbls -- a vector, of same dimension as rgn, with labels for
%               corresponding regions.
%   rgn_bnds -- a 1D cell array, of same size as rgn, with each cell
%               containing the vector of linear indices of the boundary
%               pixels of the corresponding region.
%   amatr    -- a two-column matrix of directed region adjacencies.
%               each row contains region lables of two adjacent regions.
%               the first column are "to regions", and the second column
%               are "from regions.
%   merge_rule  - char   - merge weight formula to use; currently only
%                          'default' is implemented (reserved for future
%                          alternative merge rules). Pass [] to use default.
%
%   Outputs:
%   e_wts -- a vector storing the edge weights, one for each row of directed
%            adjacency in amatr.
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
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

if nargin < 9
    lbl_map = [];
end
if nargin < 8
    verb_pref = [];
end
if nargin < 7
    f_verb = [];
end
if nargin < 6
    merge_rule = [];
end
if nargin < 5
    amatr = [];
end
if nargin < 4
    rgn_bnds =[];
end
if nargin < 3
    rgn_lbls = [];
end
if nargin < 2
    data = [];
end
if nargin < 1
    rgn = [];
end

if isempty(data) || isempty(rgn) || isempty(rgn_lbls) || isempty(amatr)
    disp('WARNING: insufficient inputs to regionWeightedEdges');
    return;
else
    e_wts = zeros(size(amatr,1),1);
    if isempty(merge_rule) %For future implementation of extra merge rules
        merge_rule = 'default'; %#ok<NASGU>
    end
    if isempty(f_verb)
        f_verb = 0;
    else
        if isempty(verb_pref)
            verb_pref = '';
        end
    end
    if length(rgn_lbls) > 1
        if f_verb>0
            disp([verb_pref 'Weighting regions...']);
        end
        % For each adjacency, determine directed edge weight
        have_map = ~isempty(lbl_map);
        for ii = 1:length(e_wts)
            % Get "to region" of current adjacency (O(1) via map, else O(R) scan)
            if have_map
                rgn_lbl_ii = lbl_map(amatr(ii,1));
            else
                rgn_lbl_ii = rgn_lbls==amatr(ii,1);
            end
            rgn_ii = rgn{rgn_lbl_ii}; % linear indices of pixels of "to region"

            % Get "from region" of current adjacency
            if have_map
                rgn_lbl_jj = lbl_map(amatr(ii,2));
            else
                rgn_lbl_jj = rgn_lbls==amatr(ii,2);
            end
            rgn_jj = rgn{rgn_lbl_jj}; % linear indices of pixels of "from region"

            % Get boundaries of current regions
            if isempty(rgn_bnds)
                % Use data if boundaries not provided
                ldata_ii = zeros(size(data));
                ldata_ii(rgn_ii) = amatr(ii,1);
                tmp_bnds = bwboundaries(ldata_ii>0,4,'holes');
                bnds_ii = [];
                for kk = 1:length(tmp_bnds)
                    bnds_ii = [bnds_ii; sub2ind(size(data),tmp_bnds{kk}(:,1),tmp_bnds{kk}(:,2))]; %#ok<*AGROW>
                end
                ldata_jj = zeros(size(data));
                ldata_jj(rgn_jj) = amatr(ii,2);
                tmp_bnds = bwboundaries(ldata_jj>0,4,'holes');
                bnds_jj = [];
                for kk = 1:length(tmp_bnds)
                    bnds_jj = [bnds_jj; sub2ind(size(data),tmp_bnds{kk}(:,1),tmp_bnds{kk}(:,2))];
                end
            else
                bnds_ii = rgn_bnds{rgn_lbl_ii};
                bnds_jj = rgn_bnds{rgn_lbl_jj};
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
% adj_bnds = bnds_ii(ismember(bnds_ii,bnds_jj));
% bnds_jj is already sorted ascending (borders are sorted at Ldata2graph's
% source and every uniquehelper update keeps them sorted), so the explicit
% sort here was redundant — it fired on all 15.7M calls to this function.
adj_mask  = ismembc(bnds_ii, bnds_jj);
adj_bnds  = bnds_ii(adj_mask);

%Max data value of the adjacent boundary pixels
max_adj = max(data(adj_bnds));

%Get the min boundary values
min_bnds_ii = min(data(bnds_ii));
min_bnds_jj = min(data(bnds_jj));

%Get the max data values
max_rgn_ii = max(data(rgn_ii));
max_rgn_jj = max(data(rgn_jj));

%Compute the weights for each
eii = 2*max_adj - min_bnds_ii - max_rgn_jj;
ejj = 2*max_adj - min_bnds_jj - max_rgn_ii;

%Take the max weight
e = max(eii,ejj);
end
