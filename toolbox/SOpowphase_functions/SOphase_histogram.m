function [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOphase, peak_selection_inds] = SOphase_histogram(varargin)
% [SO_mat, freq_cbins, SO_cbins, time_in_bin] = SO_histogram(EEG, Fs, TFpeak_freqs, TFpeak_times, freq_range, freq_binsizestep, SO_range, SO_binsizestep, SO_freqrange, artifacts, ...
%                                                            stage_exclude, t_data,time_range,  SOphase_filter, phase_freqSO_norm, rate_flag, smooth_flag, plot_flag)
%
%
%  Inputs:
%       EEG: 1xN double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of EEG (Hz) --required
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_SOphase:  Px1 - times each TF peak occurs (s) --required
%       freq_range: 1x2 double - min and max frequencies to consider in SO phase analysis 
%                   (Hz). Default = [0,40] 
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency 
%                         axis of SO phase histograms (Hz). Default = [1, 0.2]
%       SO_range: 1x2 double - min and max SO phase values (radians) to consider in SO phase analysis. 
%                 Default = [-pi, pi]
%       SO_binsizestep: 1x2 double - [size, step] SO phase bin size and step for SO phase axis 
%                            of histogram. Units are radians. Default =
%                            [(2*pi)/5, (2*pi)/100]
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation". 
%                     Default = [0.3, 1.5]
%       artifacts: 1xN logical - marks each timestep of EEG as artifact or non-artifact. Default = all false. 
%       stage_exclude: 1xN logical - marks which timestep of EEG should be excluded due to being in an 
%                      undesired stage. Default = all false.
%       t_data: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize 
%                   SO power. Default = [t_data(1), t_data(end)] 
%       phase_freqSO_norm: 1x2 logical - normalize by dividing by the sum over each dimension 
%                          of the SO phase histogram [frequency, SOphase]. Default = [true, false]
%       rate_flag: logical - histogram output in terms of TFpeaks/min instead of count. Default = true.
%       smooth_flag: logical - smooth the histogram using 5pt moving average 2D smoothing. Default = false.
%       plot_flag: logical - SO phase histogram plots. Default = false
%
%  Outputs:
%       SO_mat: SO phase histogram (SOphase x frequency)
%       freq_cbins: 1xF double - centers of the frequency bins
%       SO_cbins: 1xPH - centers of the SO phase bins
%       time_in_bin: 1xT - minutes spent in each phase bin for all selected stages 
%       prop_in_bin: 1xT - proportion of total time (all stages) in each bin spent in 
%                          the selected stages
%       peak_SOphase: 1xP double - slow oscillation phase at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are valid give the artifacts and stage_exclusion 
%                            exclusions
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
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
%Input handling
%(EEG, Fs, TFpeak_freqs, TFpeak_SOphase, freq_range, freq_binsizestep, SO_range, SO_binsizestep, artifacts, ...
%                                                            stage_exclude, t_data, SOphase_filter, phase_freqSO_norm, rate_flag, smooth_flag, plot_flag)
p = inputParser;

addRequired(p, 'EEG', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_range', [-pi,pi], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'SO_binsizestep', [(2*pi)/5, (2*pi)/100], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'SOphase_filter', []);
addOptional(p, 'artifacts', [], @(x) validateattributes(x, {'logical', 'vector'},{}));
addOptional(p, 'stage_exclude', [], @(x) validateattributes(x, {'logical', 'vector'},{}));
addOptional(p, 't_data', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'phase_freqSO_norm', [true, false], @(x) validateattributes(x,{'logical', 'vector'},{}));
addOptional(p, 'rate_flag', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'smooth_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'plot_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{}));



parse(p,varargin{:});
parser_results = struct2cell(p.Results);
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if isempty(artifacts)
    artifacts = false(size(EEG,2),1);
else
    assert(length(artifacts) == size(EEG,2),'artifacts must be the same length as EEG');
end

if isempty(stage_exclude)
    stage_exclude = false(1,size(EEG,2));
else
    assert(length(stage_exclude) == size(EEG,2),'stage_exclude must be the same length as EEG');
end

if isempty(t_data)
    t_data = (0:length(EEG)-1)/Fs;
else
    assert(length(t_data) == size(EEG,2), 't_data must be the same length as EEG');
end

if isempty(time_range)
    time_range = [min(t_data), max(t_data)];
else
    assert( (time_range(1) >= min(t_data)) & (time_range(2) <= max(t_data) ), 'lightsonoff_times cannot be outside of the time range described by "t_data"');
end

assert((SO_range(1) >= -pi) & (SO_range(2) <= pi), 'SO-phase range must be values between -pi and pi')
assert(SO_binsizestep(1) < 2*pi, 'SO-phase bin size must be less than 2*pi')


%% Compute SO phase
[SOphase, ~] = compute_SOPhase(EEG, Fs, SO_freqrange, SOphase_filter);
SOphase = SOphase';

% Replace artifact times with nans
SOphase(artifacts) = nan;

% Get bin size of SOphase
SOphase_binsize = t_data(2) - t_data(1);

%% Sort TFpeak time and frequency data
[TFpeak_times, sortinds] = sort(TFpeak_times);
TFpeak_freqs = TFpeak_freqs(sortinds);

%% Get valid peak indices
%Get indices of peaks that occur during artifact
artifact_inds_peaks = logical(interp1(t_data, double(artifacts), TFpeak_times, 'nearest'));

% Get indices of peaks that are in selected sleep stages
stage_inds_peaks = logical(interp1(t_data, double(~stage_exclude), TFpeak_times, 'nearest')); 

% Get indices of peaks that occur inside selected time range
timerange_inds_peaks = (TFpeak_times >= time_range(1)) & (TFpeak_times <= time_range(2));

% Combine all indices to select peaks that occur during valid stages/times
peak_selection_inds = stage_inds_peaks & ~artifact_inds_peaks & timerange_inds_peaks;

%% Get valid SOphase values
% Exclude unwanted stages and times
SOphase_valid_times = (t_data>=time_range(1) & t_data<=time_range(2));
SOphase_valid = ~stage_exclude & SOphase_valid_times;

%% Get SOphase at each peak time
peak_SOphase = interp1(t_data, SOphase, TFpeak_times);

%% Re-wrap phases to be between -pi and pi
peak_SOphase = mod(peak_SOphase, 2*pi) - pi;
SOphase = mod(SOphase, 2*pi) - pi;

%% Compute the SO power historgram
% Get frequency and SO phase bins
[freq_bin_edges, freq_cbins] = create_bins(freq_range, freq_binsizestep(1), freq_binsizestep(2), 'partial');
num_freqbins = length(freq_cbins);

[SO_bin_edges, SO_cbins] = create_bins(SO_range, SO_binsizestep(1), SO_binsizestep(2), 'extend');
num_SObins = length(SO_cbins);

% Display SOPH settings
if verbose
    disp(['  SO-Phase Histogram Settings' , newline,...
          '    Frequency Window Size: ' num2str(freq_binsizestep(1)) ' Hz, Window Step: ' num2str(freq_binsizestep(2)) ' Hz', newline,...
          '    Frequency Range: ', num2str(freq_range(1)) '-' num2str(freq_range(2)) ' Hz', newline,...
          '    SO-Phase Window Size: ' num2str(SO_binsizestep(1)) ', Window Step: ' num2str(SO_binsizestep(2)), newline,...
          '    SO-Phase Range: ', num2str(SO_range(1)/pi), ' (rad) - ', num2str(SO_range(2)/pi), ' (rad)'  newline, newline])
end

% Intialize SOphase * freq matrix
SO_mat = nan(num_SObins, num_freqbins);

% Initialize time in bin
time_in_bin = zeros(num_SObins,1);
prop_in_bin = zeros(num_SObins,1);

parfor s = 1:num_SObins
    
    % Check for bins that need to be wrapped because phase is circular -pi to pi
    if (SO_bin_edges(1,s) <= -pi) % Lower limit should be wrapped
        wrapped_edge_lowlim = SO_bin_edges(1,s) + (2*pi);
        time_in_bin_inds = (SOphase >= wrapped_edge_lowlim) | (SOphase < SO_bin_edges(2,s)); % time in bin index computation
        SO_inds = (peak_SOphase >= wrapped_edge_lowlim) | (peak_SOphase < SO_bin_edges(2,s)); % peaks in bin index computation
        
    elseif (SO_bin_edges(2,s) >= pi) % Upper limit should be wrapped
        wrapped_edge_highlim = SO_bin_edges(2,s) - (2*pi);
        time_in_bin_inds = (SOphase < wrapped_edge_highlim) | (SOphase >= SO_bin_edges(1,s));
        SO_inds = (peak_SOphase < wrapped_edge_highlim) | (peak_SOphase >= SO_bin_edges(1,s)); 
    
    else % Both limits are within -pi to pi, no wrapping necessary
        time_in_bin_inds = (SOphase >= SO_bin_edges(1,s)) & (SOphase < SO_bin_edges(2,s));
        SO_inds = (peak_SOphase >= SO_bin_edges(1,s)) & (peak_SOphase < SO_bin_edges(2,s));
    end
    
    % Get time in bin and proportion of time in bin
    time_in_bin(s) = (sum(time_in_bin_inds' & SOphase_valid) * SOphase_binsize) / 60;
    time_in_bin_allstages = (sum(time_in_bin_inds & SOphase_valid_times') * SOphase_binsize) / 60;
    prop_in_bin(s) = time_in_bin(s) / time_in_bin_allstages;
                
    for f = 1:num_freqbins    

        % Get indices of TFpeaks that occur in this frequency bin
        freq_inds = (TFpeak_freqs >= freq_bin_edges(1,f)) & (TFpeak_freqs < freq_bin_edges(2,f));

        % Fill histogram with count of peaks in this freq/SOphase bin
        SO_mat(s,f) = sum(SO_inds & freq_inds & peak_selection_inds);

    end
    
end

if smooth_flag == true 
    for s = 1:num_SObins % separated from parfor loop due to parallelization constraints
        SO_mat(s,:) = smooth(SO_mat(s,:));
    end
end 

if rate_flag == true
    SO_mat = SO_mat ./ time_in_bin;
end

%% Normalize along a dimension if desired
if phase_freqSO_norm(1) == true
    SO_mat = SO_mat ./ sum(SO_mat,1);
end

if phase_freqSO_norm(2) == true
    SO_mat = SO_mat ./ sum(SO_mat,2);
end

%% Plot
if plot_flag == true
   figure;
   imagesc(SO_cbins, freq_cbins, SO_mat')
   axis xy
   colormap magma
   climscale;
   colorbar;
   xlabel('SO Phase (radians)');
   ylabel('Frequency (Hz)');
end

end



