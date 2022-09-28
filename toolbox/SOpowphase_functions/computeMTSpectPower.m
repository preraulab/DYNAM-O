function [SO_power, stimes, sfreqs] = computeMTSpectPower(varargin)
% COMPUTEMTSPECTPOWER computes the slow oscillation power of timeseries data
% Usage:
%   [SO_power, stimes] = computeMTSpectPower(data, Fs, freq_range, tapers, window_params, smoothing_method, smoothing_param, interp_times, verbose)
%
%%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%% Parse input
%Input Error handling
p = inputParser;

addRequired(p,'data',@(x) validateattributes(x,{'numeric', 'vector'},{'nonempty'}));
addRequired(p,'Fs',@(x) validateattributes(x,{'numeric'},{'nonempty','numel',1}));
addOptional(p,'freq_range',[.3 1.5], @(x) validateattributes(x,{'numeric', 'vector'},{'numel',2}));
addOptional(p,'tapers',[15 29],@(x) validateattributes(x,{'numeric', 'vector'},{'numel',2}));
addOptional(p,'window_params',[30 15], @(x) validateattributes(x,{'numeric', 'vector'},{'numel',2}));
addOptional(p,'smoothing_method','none', @(x) validateattributes(x,{'char'},{}));
addOptional(p,'smoothing_param', 60*5, @(x) validateattributes(x,{'numeric'},{'numel',1}));
addOptional(p,'interp_times',[], @(x) validateattributes(x,{'numeric', 'vector'},{'real'}));
addOptional(p,'verbose',false, @(x) validateattributes(x,{'logical'},{}));
parse(p,varargin{:});
parser_results = struct2cell(p.Results);
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%% Compute SO-power
%Compute power using the MTS (data, Fs, frequency_range, taper_params, window_params, min_NFFT, detrend_opt, weighting, plot_on, verbose)

[SO_spect, stimes, sfreqs] = multitaper_spectrogram_mex(data, Fs, freq_range, tapers, window_params, [], 0, [], false, verbose);

%Compute dt
dt = stimes(2) - stimes(1);
df = sfreqs(2) - sfreqs(1);

%Takes the total power and converts to dB
SO_power = nanpow2db(sum(SO_spect,1)*df)';

%% Smooth data
if ~strcmpi(smoothing_method, 'none') && ~isempty(smoothing_param) && smoothing_param>0
    
    if verbose
        disp(['Smoothing using ' smoothing_method ' with parameter ' num2str(smoothing_param)]);
    end
    
    %Get bad indices
    bad_inds = ~isfinite(SO_power);
    
    %Interpolate big gaps in data
    t = 1:length(SO_power);
    data_fixed = interp1([0, t(~bad_inds), length(SO_power)+1], [0; SO_power(~bad_inds); 0], t)';
    
    smooth_samples   = smoothing_param/dt;        %Time in samples
    
    SO_power = smoothdata(data_fixed, smoothing_method, smooth_samples, 'omitnan' );
    
    %Return the bad values
    SO_power(bad_inds) = nan;
end

%% Interpolate data
if ~isempty(interp_times)
    SO_power = interp1(stimes, SO_power, interp_times);
end