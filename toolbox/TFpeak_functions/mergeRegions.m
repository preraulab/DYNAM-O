function [regions, borders, adj_mat, pick_update, absorbed_labels] = mergeRegions(regions,a,b,lbls,borders,adj_mat,lbl_map)
%MERGEREGIONS  Merge regions b into region a and update borders, adjacency, and weight flags
%
%   Usage:
%       [regions, borders, adj_mat, pick_update, absorbed_labels] = mergeRegions(regions, a, b, lbls, borders, adj_mat, lbl_map)
%
%   Required Inputs:
%       regions: [1 x K] cell - linear indices of pixels for each region
%       a:       integer - region label being merged into
%       b:       [1 x L] integer - region labels to merge into a
%       lbls:    [1 x K] integer - labels for each entry in regions
%
%   Optional Inputs:
%       borders: [1 x K] cell - linear indices of boundary pixels per region (default: [])
%       adj_mat: [E x 3] double - directed adjacency: [to, from, weight] (default: [])
%       lbl_map: container/array - O(1) label-to-index map; falls back to linear scan when empty (default: [])
%
%   Outputs:
%       regions:         [1 x K] cell - updated region pixel lists (merged regions now empty)
%       borders:         [1 x K] cell - updated border pixel lists
%       adj_mat:         [E' x 3] double - adjacency with duplicate and self-pairs removed
%       pick_update:     [E' x 1] logical - true for rows whose edge weight must be recomputed
%       absorbed_labels: [R x 1] integer - labels absorbed into a on this call (b plus any encircled)
%
%   See Also: mergeWshedSegment, computeMergeWeights, Ldata2graph
%
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
if nargin < 7
    lbl_map = [];
end
if nargin < 6
    adj_mat = [];
end

if nargin < 5
    borders = [];
end

%Find the corresponding label for region a
if ~isempty(lbl_map)
    a_lbl_idx = lbl_map(a); % O(1) map lookup
else
    a_lbl_idx = find(lbls==a); % fallback: O(N) linear scan
end
if ~isempty(borders)
    border_a = borders{a_lbl_idx};
end

% Accumulate labels absorbed into `a` on this call (b plus any encircled).
% Preallocated to an overestimate; trimmed before return.
absorbed_labels = zeros(length(b) + 16, 1, 'like', a);
n_absorbed = 0;

%Loop through regions that are to be merged into region a
for ii = 1:length(b)
    %Find the label index
    if ~isempty(lbl_map)
        b_lbl_idx = lbl_map(b(ii)); % O(1) map lookup
    else
        b_lbl_idx = find(lbls==b(ii)); % fallback: O(N) linear scan
    end

    %Update a to include all the b pixels
    % regions{a_lbl_idx} = unique([regions{a_lbl_idx}; regions{b_lbl_idx}]);
    regions{a_lbl_idx} = matlab.internal.math.uniquehelper([regions{a_lbl_idx}; regions{b_lbl_idx}], true, true, false);
    regions{b_lbl_idx} = [];
    n_absorbed = n_absorbed + 1;
    absorbed_labels(n_absorbed) = b(ii);

    %Update the borders
    if ~isempty(borders)
        % border_a = setxor(border_a, borders{b_lbl_idx});
        % Both border_a and B are sorted ascending (borders come out of
        % Ldata2graph sorted, and every subsequent update here goes through
        % uniquehelper which sorts). ismembc is the flag-free direct MEX
        % entry to the same machinery as ismember(...,'R2012a'), but skips
        % validatestring and stringToChar on every call — those fire ~2M
        % times in a full-night run from this exact site.
        B = borders{b_lbl_idx};
        tfa = ~ismembc(border_a, B);
        tfb = ~ismembc(B, border_a);
        border_a = matlab.internal.math.uniquehelper([border_a(tfa);B(tfb)], true, true, false);

        borders{a_lbl_idx} = border_a;
        borders{b_lbl_idx} = [];
    end

    %Update the adjacency matrix
    if ~isempty(adj_mat)
        %Connect b's neighbors to a
        cnx_b1 = adj_mat(:,1)==b(ii);
        cnx_b2 = adj_mat(:,2)==b(ii);
        adj_mat(cnx_b1,1) = a;
        adj_mat(cnx_b2,2) = a;

        %Look for regions encircled by the merge
        nbrs = [adj_mat(cnx_b1,2); adj_mat(cnx_b2,1)];
        % nbrs = setdiff(unique(nbrs),a); % neighbors of b that are not a
        % uniquehelper gives sorted-unique; removing a single scalar `a`
        % via logical indexing is ~10µs faster than setdiff's dispatch +
        % validatestring machinery, and this runs 705k times per night.
        nbrs = matlab.internal.math.uniquehelper(nbrs, true, true, false);
        nbrs = nbrs(nbrs ~= a);
        for jj = 1:length(nbrs)
            cnx1 = adj_mat(:,1)==nbrs(jj);
            cnx2 = adj_mat(:,2)==nbrs(jj);
            %merge any encircled region with a
            if all(a==adj_mat(cnx1,2)) && all(a==adj_mat(cnx2,1)) % the only neighbor is a = encircled by a
                if ~isempty(lbl_map)
                    jj_lbl_idx = lbl_map(nbrs(jj)); % O(1) map lookup
                else
                    jj_lbl_idx = find(lbls==nbrs(jj)); % fallback: O(N) linear scan
                end
                regions{a_lbl_idx} = unique([regions{a_lbl_idx}; regions{jj_lbl_idx}]);
                regions{jj_lbl_idx} = [];
                n_absorbed = n_absorbed + 1;
                if n_absorbed > numel(absorbed_labels)
                    absorbed_labels(end+16) = 0; % grow in chunks
                end
                absorbed_labels(n_absorbed) = nbrs(jj);
                if ~isempty(borders)
                    border_a = setxor(border_a, borders{jj_lbl_idx});
                    borders{a_lbl_idx} = border_a;
                    borders{jj_lbl_idx} = [];
                end
                adj_mat(cnx1,1) = a;
                adj_mat(cnx2,2) = a;
            end
        end
    end
end

%Update adjacency matrix to remove duplicate entries
cnx_a = adj_mat(:,1)==a | adj_mat(:,2)==a; % a is involved in the pair
sub_adj_mat = adj_mat(cnx_a,:);
sub_adj_mat(:,3) = NaN;
sub_adj_mat = sub_adj_mat(sub_adj_mat(:,1)~=sub_adj_mat(:,2), :); % remove the a-a pairs
% [~,u_idx] = unique(sort(sub_adj_mat(:,1:2), 2),'rows'); % remove duplicated pairs e.g., a-b, b-a
[~,u_idx] = matlab.internal.math.uniquehelper(sort(sub_adj_mat(:,1:2), 2), true, true, true); % remove duplicated pairs e.g., a-b, b-a
% [~,u_idx] = unique(sub_adj_mat(:,1:2),'rows'); % this old line keeps duplicated pairs and is undesirable

%Update the adjacency matrix with unique pairs involving a
adj_mat = [adj_mat(~cnx_a,:); sub_adj_mat(u_idx,:)];

%Identify which edge weights need to be updated
pick_update = false(size(adj_mat, 1), 1);
pick_update((end-length(u_idx)+1):end) = true;

%Trim absorbed label buffer to actual size
absorbed_labels = absorbed_labels(1:n_absorbed);
