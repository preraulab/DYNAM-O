function full_lidx = subLidx2FullLidx(sub_lidx,size_sub,top_left,size_full)
%SUBLIDX2FULLLIDX converts linear pixel indices within a subregion of an image into
%the linear pixel indices within the full image.
%
% Usage:
%   full_lidx = subLidx2FullLidx(sub_lidx,size_sub,top_left,size_full)
%
%   INPUTS:
%     sub_lidx  - vector of linear pixel indices in subregion
%     size_sub  - size, [num_rows num_cols], of subregion
%     top_left  - location, [row col], of top left pixel of subregion within full image
%     size_full - size, [num_rows num_cols], of subregion
%
%   OUTPUTS:
%     full_lidx - vector of linear pixel indices in full image
%

% [sub_row, sub_col] = ind2sub(size_sub,sub_lidx);
vi = rem(sub_lidx-1, size_sub(1)) + 1;
sub_col = ((sub_lidx - vi)/size_sub(1) + 1);
sub_row = vi;

sub_row = sub_row + top_left(1) - 1;
sub_col = sub_col + top_left(2) - 1;

% full_lidx = sub2ind(size_full,sub_row,sub_col);
full_lidx = sub_row + (sub_col-1)*size_full(1);

end
