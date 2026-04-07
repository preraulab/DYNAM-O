function [ Ldata ] = cell2Ldata(rgn, data_size, Lborders, min_area)
%CELL2LDATA  Convert a cell array of region pixel indices to a labeled 2D image matrix
%
%   Usage:
%       Ldata = cell2Ldata(rgn, data_size, Lborders, min_area)
%
%   Inputs:
%       rgn:       cell array - each cell contains a vector of linear pixel indices for a region
%       data_size: [1x2] double - [num_rows, num_cols] size of the full image
%       Lborders:  cell array - vector lists of linear idx of border pixels for each region.
%                  If given, ASSUMES idx in Lborders corresponds to region label. (default: [])
%       min_area:  double - minimum region size; smaller regions are zeroed out (default: 0)
%
%   Outputs:
%       Ldata:     2D double matrix - labeled image data. 0 indicates border or unlabeled pixels.
%
%   Citation:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification", Sleep, 2022; zsac223.
%       https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

if nargin < 4
    min_area = 0;
end

if nargin < 3
    Lborders = [];
end

if isempty(Lborders)
    Lborders = cell(length(rgn),1);
end

Ldata = zeros(data_size);
for ii = 1:length(rgn)  
    ii_pixels = rgn{ii};
    if length(ii_pixels) >= min_area
        Ldata(ii_pixels)=ii;
        if ~isempty(Lborders{ii})
            Ldata(Lborders{ii}) = 0;
        end
    end
end

