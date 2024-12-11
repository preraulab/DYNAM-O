function [regions, borders, adj_mat, pick_update] = mergeRegions(regions,a,b,lbls,borders,adj_mat)
%MERGEREGIONS updates the pixel lists in region and borders and the adjacencies in 
% adj_mat according to mergion regions b into region a. It also returns an 
% indicator for what edge weights need to be updated
%
% Usage: 
%   [regions, borders, adj_mat, pick_update] = mergeRegions(regions,a,b,lbls,borders,adj_mat)
%
% INPUTS: 
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
% OUTPUTS:
%   regions, borders, adj_mat -- versions of inputs after merger 
%   pick_update        -- logical vector indicating weights that need to be
%                         updated
%
%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, 
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis 
%       for Electroencephalographic Phenotyping and Biomarker Identification, 
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

if nargin < 6
    adj_mat = [];
end

if nargin < 5
    borders = [];
end

if nargin < 4
    lbls = [];
end

%Creates labels if not present
if isempty(lbls)
   lbls = unique(regions(:,2)); 
end

%Find the corresponding label for region a
a_lbl_idx = find(lbls==a);        
if ~isempty(borders)
    border_a = borders{a_lbl_idx};
end

%Loop through regions that are to be merged into region a
for ii = 1:length(b)
    %Find the label index
    b_lbl_idx = lbls==b(ii);

    %Get the pixels in region b
    region_b_lidx = regions{b_lbl_idx};
    
    %Update a to include all the b pixels
    regions{a_lbl_idx} = unique([regions{a_lbl_idx}; region_b_lidx]);
    regions{b_lbl_idx} = [];
    
    %Update the borders
    if ~isempty(borders)
        border_b = borders{b_lbl_idx};
        border_a = setxor(border_a,border_b);
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

        % Look for regions encircled by the merge
        nbrs = [adj_mat(cnx_b1,2); adj_mat(cnx_b2,1)];
        %Get all the neighbors of a
        nbrs = setdiff(unique(nbrs),a);
        for jj = 1:length(nbrs)
            cnx1 = adj_mat(:,1)==nbrs(jj);
            cnx2 = adj_mat(:,2)==nbrs(jj);

            %Merge the encircled region with a
            if ~any(a~=adj_mat(cnx1,2)) && ~any(a~=adj_mat(cnx2,1))   

                ii_lbl_idx = lbls==nbrs(jj);
                region_ii_lidx = regions{ii_lbl_idx};
                regions{a_lbl_idx} = unique([regions{a_lbl_idx}; region_ii_lidx]);
                regions{ii_lbl_idx} = [];
                border_ii = borders{ii_lbl_idx};
                border_a = setxor(border_a,border_ii);
                borders{a_lbl_idx} = border_a;
                borders{ii_lbl_idx} = [];
                
                adj_mat(cnx1,1) = a;
                adj_mat(cnx2,2) = a;
            end 
        end 
    end
end

% Update adjacency matrix to remove duplicate entries
cnx_a = adj_mat(:,1)==a | adj_mat(:,2)==a;
sub_adj_mat = adj_mat(cnx_a,:);
sub_adj_mat(:,3) = NaN;
sub_adj_mat = sub_adj_mat(sub_adj_mat(:,1)~=sub_adj_mat(:,2),:);
[~,u_idx] = unique(sort(sub_adj_mat(:,1:2), 2),'rows');
%[~,u_idx] = unique(sub_adj_mat(:,1:2),'rows');

%Update the adjacency matrix with unique pairs
adj_mat = [adj_mat(~cnx_a,:); sub_adj_mat(u_idx,:)];

%Identify which edge weights need to be updated
pick_update = false(size(adj_mat, 1), 1);
pick_update((end-length(u_idx)+1):end) = true;
