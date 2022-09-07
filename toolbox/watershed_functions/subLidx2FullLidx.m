function full_lidx = subLidx2FullLidx(sub_lidx,size_sub,top_left,size_full)
%subLidx2FullLidx converts linear pixel indices within a subregion of an image into
%the linear pixel indices within the full image.
%   INPUTS:  
%     sub_lidx  - vector of linear pixel indices in subregion    
%     size_sub  - size, [num_rows num_cols], of subregion
%     top_left  - location, [row col], of top left pixel of subregion within full image 
%     size_full - size, [num_rows num_cols], of subregion
%
%   OUTPUTS: 
%     full_lidx - vector of linear pixel indices in full image
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
    [sub_row, sub_col] = ind2sub(size_sub,sub_lidx);
    sub_row = sub_row + top_left(1) - 1;
    sub_col = sub_col + top_left(2) - 1;
    full_lidx = sub2ind(size_full,sub_row,sub_col);

end

