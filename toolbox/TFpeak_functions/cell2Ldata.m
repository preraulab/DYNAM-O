function [ Ldata ] = cell2Ldata( rgn, data_size, Lborders , min_area)
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
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
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
%     if ii == 841
%        disp(ii); 
%     end
    ii_pixels = rgn{ii};
    if length(ii_pixels) >= min_area
        Ldata(ii_pixels)=ii;
        if ~isempty(Lborders{ii})
            Ldata(Lborders{ii}) = 0;
        end
    end
end

