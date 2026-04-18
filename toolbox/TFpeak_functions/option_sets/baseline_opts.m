function opts = baseline_opts(varargin)
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
%% Parse inputs
p = inputParser;

%****************************************
% Generate Baseline Options Structure
%****************************************
%Sleep stages to include for baseline computation
addOptional(p, 'baseline_stages',[1,2,3,4,5], @(x) validateattributes(x,{'numeric'},{'real','vector'}));
%Logical indices for time points to exclude for baseline computation
addOptional(p, 'baseline_exclude',logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));
%Percentile to use for fixed baseline computation
addOptional(p, 'baseline_ptile',2, @(x) validateattributes(x,{'numeric'},{'real','scalar'}));
%Start and stop times for baseline trimming OR integer representing buffer time (min) around the first and last sleep period.
addOptional(p, 'baseline_trim',[-inf inf], @(x) isa(x,'numeric') && length(x) <= 2);

parse(p,varargin{:});
opts = p.Results;
