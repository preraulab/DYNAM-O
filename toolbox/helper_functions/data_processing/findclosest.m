%FINDCLOSEST  Compares two vectors A and B, and finds the elements in A closest to B
%
%   Usage:
%       [vals inds]=findclosest(A, B)
%
%   Input:
%   A: 1xN vector of numeric values
%   B: 1XM vector of numeric values to compare to those in A
%
%   Output:
%   vals: the values of the elements in A that are closest to B
%   inds: the indices of the values in A to which those in B are closest
%
%   Example:
%
%         %Create data sets
%         A=[-1 5 74 2 9 -45 23 75 23]
%         B=[-3.4 5.6 9.45 -100]
%
%         %Define events
%         [vals inds]=findclosest(A, B)
% 
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://harvard.edu
%   GITHUB     https://github.com
%
%   CITATION
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
function [vals, inds]=findclosest(A, B)
inds=zeros(1,length(B));

%Use fast matrix method for smaller data sets
if length(A)*length(B)*2<5000000
    [~, inds]=min(abs(ones(length(A),1)*B(:)'-A(:)*ones(1,length(B))));
else %Use slow method for large sets
    %     disp('Datasets large. Switching to iterative method');
    parfor ii=1:length(B)
        [~, inds(ii)]=min(abs(A-B(ii)));
    end
end

vals=A(inds);