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
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================

% [sub_row, sub_col] = ind2sub(size_sub,sub_lidx);
vi = rem(sub_lidx-1, size_sub(1)) + 1;
sub_col = ((sub_lidx - vi)/size_sub(1) + 1);
sub_row = vi;

sub_row = sub_row + top_left(1) - 1;
sub_col = sub_col + top_left(2) - 1;

% full_lidx = sub2ind(size_full,sub_row,sub_col);
full_lidx = sub_row + (sub_col-1)*size_full(1);

end
