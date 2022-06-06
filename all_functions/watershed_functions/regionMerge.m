function [rgn, brdrs, ematr, pick_update] = regionMerge(rgn,a,b,lbls,brdrs,ematr)
%regionMerge updates the pixel lists in rgn and borders and the adjacencies in 
% ematr according to mergion regions b into region a. It also returns an 
% indicator for what edge weights need to be updated
%
% INPUTS: 
%   rgn   -- a 1D cell array with each cell containing a vector of linear 
%            indices of the pixels in the region.
%   a     -- region label to be merged into
%   b     -- vector of region labels to be merged into a
%   lbls  -- a vector, of same dimension as rgn, with labels for
%            corresponding regions.
%   brdrs -- a 1D cell array, of same size as rgn, with each cell
%            containing the vector of linear indices of the boundary 
%            pixels of the corresponding region.
%   ematr -- a three-column matrix of directed region adjacency weights. 
%            each row contains region lables of two adjacent regions.
%            the first column are "to regions", the second column
%            are "from regions, and the third column is the weight.
%
% OUTPUTS:
%   rgns, brdrs, ematr -- versions of inputs after merger 
%   pick_update        -- logical vector indicating weights that need to be
%                         updated
%
%   Copyright 2022 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
% Created on: 20171016 -- forked from version in wshed1;
% Modified: 20190422 -- avoids unique in fill-hole
%           20190215 -- cleaned up for toolbox
%
%**********************************************************************


if nargin < 6
    ematr = [];
end
if nargin < 5
    brdrs = [];
end
if nargin < 4
    lbls = [];
end

if isempty(lbls)
   lbls = unique(rgn(:,2)); 
end

a_lbl_idx = find(lbls==a);        
if ~isempty(brdrs)
    brdr_a = brdrs{a_lbl_idx};
end

%***
% Debug segment to check for prior holes 
%***
% nbrs = ematr(ematr(:,1)==a,2);
% nbrs = [nbrs; ematr(ematr(:,2)==a,1)];
% nbrs = unique(nbrs);
% for ii = 1:length(nbrs)
%     cnx1 = ematr(:,1)==nbrs(ii);
%     cnx2 = ematr(:,2)==nbrs(ii);
%     tmp = unique([ematr(cnx1,2); ematr(cnx2,1)]);
%     if length(tmp)==1 && tmp(1)==a
%         disp(['found a prior hole ' num2str(nbrs(ii)) ' in ' num2str(a)]);
%         disp(b);
%     end
% end


for ii = 1:length(b)
    b_lbl_idx = lbls==b(ii);
    rgn_b_lidx = rgn{b_lbl_idx};
    
    rgn{a_lbl_idx} = unique([rgn{a_lbl_idx}; rgn_b_lidx]);
    rgn{b_lbl_idx} = [];
    
    if ~isempty(brdrs)
        brdr_b = brdrs{b_lbl_idx};
        brdr_a = setxor(brdr_a,brdr_b);
        brdrs{a_lbl_idx} = brdr_a;
        brdrs{b_lbl_idx} = [];
    end
    
    if ~isempty(ematr)
        cnx_b1 = ematr(:,1)==b(ii);
        cnx_b2 = ematr(:,2)==b(ii);
        ematr(cnx_b1,1) = a;
        ematr(cnx_b2,2) = a;
        
%***
% Old version that checks all neighbors to fill 
%***
%         cnx_a = ematr(:,1)==a | ematr(:,2)==a;
%         ematr(cnx_a,3) = NaN;
%         [~,uidx] = unique(ematr(:,1:2),'rows');
%         ematr = ematr(uidx,:);
%         ematr = ematr(ematr(:,1)~=ematr(:,2),:);
%         nbrs = [ematr(ematr(:,1)==a,2); ematr(ematr(:,2)==a,1)];
%         nbrs = unique(nbrs);

%***
% Second version that looks for single-region holes
%***
        nbrs = [ematr(cnx_b1,2); ematr(cnx_b2,1)];
        nbrs = setdiff(unique(nbrs),a);
        for jj = 1:length(nbrs)
            cnx1 = ematr(:,1)==nbrs(jj);
            cnx2 = ematr(:,2)==nbrs(jj);
            % tmp = unique([ematr(cnx1,2); ematr(cnx2,1)]);
            if ~any(a~=ematr(cnx1,2)) && ~any(a~=ematr(cnx2,1))   % length(tmp)==1 && tmp(1)==a
                % disp(['filling hole: ' num2str(nbrs(ii)) ' into ' num2str(a)]);
                
                ii_lbl_idx = lbls==nbrs(jj);
                rgn_ii_lidx = rgn{ii_lbl_idx};
                rgn{a_lbl_idx} = unique([rgn{a_lbl_idx}; rgn_ii_lidx]);
                rgn{ii_lbl_idx} = [];
                brdr_ii = brdrs{ii_lbl_idx};
                brdr_a = setxor(brdr_a,brdr_ii);
                brdrs{a_lbl_idx} = brdr_a;
                brdrs{ii_lbl_idx} = [];
                
                ematr(cnx1,1) = a;
                ematr(cnx2,2) = a;
            end
            
        end
        
        
    end
    
%     if ~isempty(chlds)
%         if isempty(chlds{a_lbl_idx})
%             chlds{a_lbl_idx} = [];
%         end
%         chlds{a_lbl_idx} = unique([chlds{a_lbl_idx} b chlds{b_lbl_idx}]);
%     end
end

cnx_a = ematr(:,1)==a | ematr(:,2)==a;
sub_ematr = ematr(cnx_a,:);
sub_ematr(:,3) = NaN;
sub_ematr = sub_ematr(sub_ematr(:,1)~=sub_ematr(:,2),:);
[~,u_idx] = unique(sub_ematr(:,1:2),'rows');
ematr = [ematr(~cnx_a,:); sub_ematr(u_idx,:)];
pick_update = false(size(ematr(:,3)));
pick_update((end-length(u_idx)+1):end) = true;



