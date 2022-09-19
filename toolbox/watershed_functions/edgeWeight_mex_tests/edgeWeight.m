function e = edgeWeight(bnds_ii,rgn_jj,data)
% edgeWeight computes the directed edge weight from region jj to region ii.
% The weight is (the difference between the maximum of the adjacency boundary 
% and the minimum of the ii boundary) minus (the difference between the
% maximum of the jj region and the maximum of the adjacency boundary).
%
% INPUTS:
%   merge_rule --
%   bnds_ii -- vector of linear indices of boundary of "to region"
%   rgn_jj  -- vector of linear indices of pixels of "from region"
%   data    -- 2D image data from which regions were defined
%
% OUTPUTS:
%   e       -- edge weight

% fastest version to get intersection of "to region" boundary with "from region" 
% adj_bnd = bnds_ii(ismember(bnds_ii,rgn_jj));


%Add switch case to add new merge rules
% switch merge_rule
%     case 'default'

% c = max(data(adj_bnd)) - min(data(bnds_ii));
% d = max(data(rgn_jj)) - max(data(adj_bnd));
% e = c - d;

%adj_bnd = bnds_ii(ismembc(bnds_ii,sort(rgn_jj)));
%e = 2*max(data(adj_bnd)) - min(data(bnds_ii)) - max(data(rgn_jj)); % equivalent to above lines




end

