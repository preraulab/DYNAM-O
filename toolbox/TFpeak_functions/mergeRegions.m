function [regions, borders, adj_mat, pick_update] = mergeRegions(regions,a,b,lbls,borders,adj_mat,lbl_map)
%MERGEREGIONS updates the pixel lists in region and borders and the adjacencies in
% adj_mat according to mergion regions b into region a. It also returns an
% indicator for what edge weights need to be updated
%
% Usage:
%   [regions, borders, adj_mat, pick_update] = mergeRegions(regions,a,b,lbls,borders,adj_mat)
%
%   Inputs:
%   regions   -- a 1D cell array with each cell containing a vector of linear
%            indices of the pixels in the region.
%   a     -- region label to be merged into
%   b     -- vector of region labels to be merged into a
%   lbls  -- a vector, of same dimension as regions, with labels for
%            corresponding regions.
%   borders -- a 1D cell array, of same size as regions, with each cell
%            containing the vector of linear indices of the boundary
%            pixels of the corresponding region.
%   adj_mat -- a three-column matrix of directed region adjacency weights.
%            each row contains region lables of two adjacent regions.
%            the first column are "to regions", the second column
%            are "from regions, and the third column is the weight.
%
%   Outputs:
%   regions, borders, adj_mat -- versions of inputs after merger
%   pick_update        -- logical vector indicating weights that need to be
%                         updated
%
%
%   Citation:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification", Sleep, 2022; zsac223.
%       https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

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

    %Update the borders
    if ~isempty(borders)
        % border_a = setxor(border_a, borders{b_lbl_idx});
        % Stripping down setxor to the key commands
        B = borders{b_lbl_idx};
        tfa = ~ismember(border_a,B,'R2012a');
        tfb = ~ismember(B,border_a,'R2012a');
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
        nbrs = setdiff(matlab.internal.math.uniquehelper(nbrs, true, true, false),a); % neighbors of b that are not a
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
