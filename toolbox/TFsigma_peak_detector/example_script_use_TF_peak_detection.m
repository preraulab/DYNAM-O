close all
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
clear all
clc

% simply run
load('example_data')

% run the TF_peak_detection wrapper function
[ spindle_table, spectrogram_used, fpeak_proms, noise_peak_times, lowbw_TFpeaks, fh ] = TF_peak_detection(EEG, Fs, [stage_times; stages]');

% to use the old routine of kmeans clustering on log prominence
[ spindle_table, spectrogram_used, fpeak_proms, noise_peak_times, lowbw_TFpeaks, fh ] = TF_peak_detection(EEG, Fs, [stage_times; stages]', 'signal_selection_routine', 'sleep2021');
