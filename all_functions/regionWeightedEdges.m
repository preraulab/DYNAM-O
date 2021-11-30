function e_wts = regionWeightedEdges(rgn,data,rgn_lbls,rgn_bnds,amatr,merge_rule,f_verb,verb_pref)
% regionWeightedEdges determines the weights of directed adjacencies between regions 
% in a segmented 2D image. The weights are computed by edgeWeight, which is
% internalized for speed.
%
% INPUTS: 
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
%   merge_rule --
%
% OUTPUTS: 
%   e_wts -- a vector storing the edge weights, one for each row of directed 
%            adjacency in amatr.
%
% Created by: Patrick Stokes
% Created:  20171015 -- forked from version in wshed1
% Modified: 20190219 -- cleaned up for toolbox
%           20171016 -- to handle cell array form of rgn
%

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
else
    e_wts = zeros(size(amatr,1),1);
    if isempty(merge_rule)
        merge_rule = 'absolute';
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
        for ii = 1:length(e_wts)
            % Get "to region" of current adjacency
            rgn_lbl_ii = rgn_lbls==amatr(ii,1); % logical indicating label index of "to region"
            rgn_ii = rgn{rgn_lbl_ii}; % linear indices of pixels of "to region"
            
            % Get "from region" of current adjacency
            rgn_lbl_jj = rgn_lbls==amatr(ii,2); % logical indicating label index of "from region"
            rgn_jj = rgn{rgn_lbl_jj}; % linear indices of pixels of "from region"
            
            % Get boundaries of current regions
            if isempty(rgn_bnds)
                % Use data if boundaries not provided
                ldata_ii = zeros(size(data));
                ldata_ii(rgn_ii) = amatr(ii,1);
                tmp_bnds = bwboundaries(ldata_ii>0,4,'holes');
                bnds_ii = [];
                for kk = 1:length(tmp_bnds)
                    bnds_ii = [bnds_ii; sub2ind(size(data),tmp_bnds{kk}(:,1),tmp_bnds{kk}(:,2))];
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
            e_wts(ii) = edgeWeight(rgn_ii,bnds_ii,rgn_jj,bnds_jj,data,merge_rule);
        end
    else
        if f_verb>0
            disp([verb_pref 'Single region encountered in weighting.']);
        end
    end
end
end

function e = edgeWeight(rgn_ii,bnds_ii,rgn_jj,bnds_jj,data,merge_rule)
% edgeWeight computes the directed edge weight from region jj to region ii.
% The weight is (the difference between the maximum of the adjacency boundary 
% and the minimum of the ii boundary) minus (the difference between the
% maximum of the jj region and the maximum of the adjacency boundary).
%
% INPUTS:
%   merge_rule --
%   rgn_ii  -- vector of linear indices of pixels of "to region"
%   bnds_ii -- vector of linear indices of boundary of "to region"
%   rgn_jj  -- vector of linear indices of pixels of "from region"
%   bnds_jj -- vector of linear indices of boundary of "from region"
%   data    -- 2D image data from which regions were defined
%
% OUTPUTS:
%   e       -- edge weight
%
% Created by: Patrick Stokes
% Created:  20171015 -- forked from version in wshed1
% Modified: 20190219 -- cleaned up for toolbox
%

% fastest version to get intersection of "to region" boundary with "from region"
adj_bnd = bnds_ii(builtin('_ismemberhelper',bnds_ii,sort(rgn_jj)));

switch merge_rule
    case {'absolute','abs'}
        % c = max(data(adj_bnd)) - min(data(bnds_ii));
        % d = max(data(rgn_jj)) - max(data(adj_bnd));
        % e = c - d;
        e = 2*max(data(adj_bnd)) - min(data(bnds_ii)) - max(data(rgn_jj)); % equivalent to lines 144-146
    case {'relative', 'rel'}
        e = 1 / (max(data(rgn_ii)) / (max(data(adj_bnd)) - min(data(adj_bnd)))); % alternative merge rule
end

end

