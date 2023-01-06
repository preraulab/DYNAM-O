function [ BWdata ] = cell2BWBorders( rgn, data_size, Lborders , min_area)
%region2ldata takes rgn matrix and converts to labeled 2D form
%
% OUTPUTS:
%   rgn       -- two-column matrix of labeled pixels
%                first col is linear idx of pixels, second col is region label 
%                border pixels are labeled twice
%   data_size -- [num_rows num_cols]
%   Lborders  -- 1D cell array of vector lists of linear idx of border pixels for each region
%                If given, ASSUMES idx in Lborders corresponds to region
%                label.
%   min_area  -- size below which region is zeroed out and ignored. Defaults to zero.  
% INPUTS:
%   Ldata   -- 2D matrix of image data. 0 indicates border pixels.
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
% Created on: 
% Modified: 20170908 -- Added min_area option to zero-out small regions 
%           20170906 -- Commented and cleaned up
%

if nargin < 4
    min_area = 0;
end

BWdata = zeros(data_size);
for ii = 1:length(Lborders)  
    ii_pixels = rgn{ii};
    if length(ii_pixels) >= min_area
        BWdata(Lborders{ii}) = 1;
    end
end

