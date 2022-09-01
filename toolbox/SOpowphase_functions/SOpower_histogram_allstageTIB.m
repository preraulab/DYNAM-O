function [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOpower_norm, peak_selection_inds, SOpower_norm, ptile, SOpow_times] = SOpower_histogram_allstageTIB(varargin)
% [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOpower_norm, peak_selection_inds] = ...
%                           SO_histogram(EEG, Fs, TFpeak_freqs, TFpeak_times, freq_range, freq_binsizestep, ...
%                                        SO_range, SO_binsizestep, SOfreq_range, artifacts, ...
%                                        stage_exclude, t, norm_method, min_time_in_bin, lightsonoff_times, ...
%                                        pow_freqSO_norm, rate_flag, smooth_flag, plot_flag)
%
%  Inputs:
%       EEG: 1xN double - timeseries EEG data --required
%       Fs: numerical - sampling frequency of EEG (Hz) --required
%       TFpeak_freqs: Px1 - frequency each TF peak occurs (Hz) --required
%       TFpeak_SOphase:  Px1 - times each TF peak occurs (s) --required
%       stages: 1xN double - sleep stage for each EEG timepoint --required
%       freq_range: 1x2 double - min and max frequencies to consider in SO phase analysis 
%                   (Hz). Default = [0,40] 
%       freq_binsizestep: 1x2 double - [size, step] frequency bin size and bin step for frequency 
%                         axis of SO phase histograms (Hz). Default = [0.5, 0.1]
%       SO_range: 1x2 double - min and max SO phase values (radians) to consider in SO phase analysis. 
%                 Default = [0, 1]
%       SO_binsizestep: 1x2 double - [size, step] SO phase bin size and step for SO phase axis 
%                            of histogram. Units are radians. Default = [0.05, 0.01]
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation". 
%                     Default = [0.3, 1.5]
%       artifacts: 1xN logical - marks each timestep of EEG as artifact or non-artifact. Default = all false. 
%       stage_exclude: 1xN logical - marks which timestep of EEG should be excluded due to being in an 
%                      undesired stage. Default = all false.
%       t: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       norm_method: char - normalization method for SOpower. 'percentile' (default), 'shift', 'absolute'.
%       min_time_in_bin: numerical - time (minutes) required in each SO power bin to include 
%                              in SO power analysis. Otherwise all values in that SO power bin will 
%                              be NaN. Default = 1.
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize 
%                   SO power. Default = [t(1), t(end)] 
%       pow_freqSO_norm: 1x2 logical - normalize by dividing by the sum over each dimension 
%                          of the SO phase histogram [frequency, SOphase]. Default = [true, false]
%       rate_flag: logical - histogram output in terms of TFpeaks/min instead of count. Default = true.
%       smooth_flag: logical - smooth the histogram using 5pt moving average 2D smoothing. Default = false.
%       plot_flag: logical - SO power histogram plots. Default = false
%
%  Outputs:
%       SO_mat: SO power histogram (SOpower x frequency)
%       freq_cbins: 1xF double - centers of the frequency bins
%       SO_cbins: 1xPO double - centers of the power SO bins
%       time_in_bin: 1xT double - minutes spent in each phase bin for all selected stages 
%       prop_in_bin: 1xT double - proportion of total time (all stages) in each bin spent in 
%                          the selected stages
%       peak_SOpower_norm: 1xP double - normalized slow oscillation power at each TFpeak
%       peak_selection_inds: 1xP logical - which TFpeaks are valid give the artifacts and stage_exclusion 
%                            exclusions
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Authors: Patrick Stokes, Thomas Possidente, Michael Prerau
%
%   Last modified:
%       - Created - Tom P. 11/16/2021
%
%
%%%************************************************************************************%%%

%% Parse input

p = inputParser;
addRequired(p, 'EEG', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p,'TFpeak_freqs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p,'TFpeak_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p,'stages', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [0.5, 0.1], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_range', [0,1], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'SO_binsizestep', [0.05, 0.01], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'artifacts', [], @(x) validateattributes(x, {'logical', 'vector'},{}));
addOptional(p, 'stage_exclude', [], @(x) validateattributes(x, {'logical', 'vector'},{}));
addOptional(p, 't', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'norm_method', 'percentile', @(x) validateattributes(x, {'char'},{}));
addOptional(p, 'min_time_in_bin', 1, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan', 'nonnegative','integer'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'pow_freqSO_norm', [false, false], @(x) validateattributes(x,{'logical', 'vector'},{}));
addOptional(p, 'rate_flag', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'smooth_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'plot_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'proportion_freqrange', [0.3, 30], @(x) validateattributes(x, {'numeric','vector'},{'real','finite','nonnan'}));

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
    stage_exclude = false(size(EEG,2),1);
else
    assert(length(stage_exclude) == size(EEG,2),'stage_exclude must be the same length as EEG');
end

if isempty(t)
    t = (0:length(EEG)-1)/Fs;
else
    assert(length(t) == size(EEG,2), 't must be the same length as EEG');
end

if isempty(time_range)
    time_range = [min(t), max(t)];
else
    assert( (time_range(1) >= min(t)) & (time_range(2) <= max(t) ), 'lightsonoff_times cannot be outside of the time range described by "t"');
end


%% replace artifact timepoints with NaNs
nanEEG = EEG;
nanEEG(artifacts) = nan; 

%% Compute SO power
if ~strcmpi(norm_method, {'oof', 'OOF', 'one over f', '1/f'})
    [SOpower, SOpow_times] = compute_mtspect_power(nanEEG, Fs, 'freq_range', SO_freqrange);
    SOpow_full_binsize = SOpow_times(2) - SOpow_times(1);
end

% Normalize SO power
switch norm_method
    case {'oof', 'OOF', 'one over f', '1/f'}
        [oof_spect, oof_stimes, oof_sfreqs] = multitaper_spectrogram_mex(EEG, Fs, [0, 50], [15,29], [30, 30], [], 'off', [], false);
        sfreqs_inds = (oof_sfreqs > 15) & (oof_sfreqs <= 45);
        oof_spect = oof_spect(sfreqs_inds, :); % nanpow2db
        oof_sfreqs = oof_sfreqs(sfreqs_inds);
        [oof_slopes] = oof_slope_calc(oof_spect', oof_stimes, oof_sfreqs);
        SOpower_norm = oof_slopes;
        SOpower_norm(SOpower_norm==0) = nan;
        SOpow_times = oof_stimes;
        SOpow_full_binsize = oof_stimes(2) - oof_stimes(1);
        ptile = [];

    case {'proportion', 'normalized'}
        [proppower, ~] = compute_mtspect_power(nanEEG, Fs, 'freq_range', [proportion_freqrange(1), proportion_freqrange(2)]);
        SOpower_norm = db2pow(SOpower)./db2pow(proppower);
        ptile = [];
    
    case {'percentile', 'percent'}
        low_val =  1;
        high_val =  99;
        ptile = prctile(SOpower(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), [low_val, high_val]);
        SOpower_norm = SOpower-ptile(1);
        SOpower_norm = SOpower_norm/(ptile(2) - ptile(1));
        
    case 'shift'
        low_val =  5; 
        ptile = prctile(SOpower(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), low_val);
        SOpower_norm = SOpower-ptile(1);

    case {'absolute', 'none'}
        SOpower_norm = SOpower;
        ptile = [];
        
    otherwise
        error(['Normalization method "', norm_method, '" not recognized']);
end

%% Sort TFpeak time and frequency data
[TFpeak_times, sortinds] = sort(TFpeak_times);
TFpeak_freqs = TFpeak_freqs(sortinds);

%% Get valid peak indices
%Get indices of peaks that occur during artifact
artifact_inds_peaks = logical(interp1(t, double(artifacts), TFpeak_times, 'nearest'));

% Get indices of peaks that are in selected sleep stages
stage_inds_peaks = logical(interp1(t, double(~stage_exclude), TFpeak_times, 'nearest')); 

% Get indices of peaks that occur inside selected time range
timerange_inds_peaks = (TFpeak_times >= time_range(1)) & (TFpeak_times <= time_range(2));

% Combine all indices to select peaks that occur during valid stages/times
peak_selection_inds = stage_inds_peaks & ~artifact_inds_peaks & timerange_inds_peaks;

%% Get valid SOpower values
% Exclude unwanted stages and times
SOpower_stages_valid = logical(interp1(t, double(~stage_exclude), SOpow_times, 'nearest'));
SOpower_times_valid = (SOpow_times>=time_range(1) & SOpow_times<=time_range(2));
SOpower_valid = SOpower_stages_valid & SOpower_times_valid;

%% Get SOpower at each peak time
peak_SOpower_norm = interp1(SOpow_times, SOpower_norm, TFpeak_times, 'nearest');

%% Compute the SO power historgram
% Get frequency and SO power bins
[freq_bin_edges, freq_cbins] = create_bins(freq_range, freq_binsizestep(1), freq_binsizestep(2), 'partial');
num_freqbins = length(freq_cbins);

[SO_bin_edges, SO_cbins] = create_bins(SO_range, SO_binsizestep(1), SO_binsizestep(2), 'partial');
num_SObins = length(SO_cbins);

% Interpolate stages to SOpow times
stages_interp = interp1(t, stages, SOpow_times, 'nearest');

% Intialize SOpow * freq matrix
SO_mat = nan(num_SObins, num_freqbins);

% Initialize time in bin
time_in_bin = zeros(num_SObins,5);
prop_in_bin = zeros(num_SObins,5);

for s = 1:num_SObins
   
    % Get indices of SOpow that occur in this SOpow bin 
    TIB_inds = (SOpower_norm >= SO_bin_edges(1,s)) & (SOpower_norm < SO_bin_edges(2,s));
    
    % Get indices of TFpeaks that occur in this SOpow bin
    SO_inds = (peak_SOpower_norm >= SO_bin_edges(1,s)) & (peak_SOpower_norm < SO_bin_edges(2,s));
    
    % Find time in bin (min)
    for tt = 1:5
        time_in_bin(s,tt) = (sum(TIB_inds & SOpower_valid' & stages_interp'==tt) * SOpow_full_binsize)/60;
    end
    time_in_bin_allstages = (sum(TIB_inds & SOpower_times_valid') .* SOpow_full_binsize)/60;
    prop_in_bin(s,:) = time_in_bin(s,:)./time_in_bin_allstages;
    
    % if less than threshold time in SO bin, whole column of SO power hist should be nan
    if sum(time_in_bin(s,:)) < min_time_in_bin
        time_in_bin(s,:) = nan;
        prop_in_bin(s,:) = nan;
        continue
    end 
    
    
    if sum(SO_inds & peak_selection_inds) >= 1
        
        for f = 1:num_freqbins    
            
            % Get indices of TFpeaks that occur in this freq bin
            freq_inds = (TFpeak_freqs >= freq_bin_edges(1,f)) & (TFpeak_freqs < freq_bin_edges(2,f));
            
            % Fill histogram with count of peaks in this freq/SOpow bin
            SO_mat(s,f) = sum(SO_inds & freq_inds & peak_selection_inds);
            
        end
        
    else
        SO_mat(s,:) = 0;
    end
    
    if smooth_flag == true 
        SO_mat(s,:) = smooth(SO_mat(s,:));
    end 
    
    if rate_flag == true
        SO_mat(s,:) = SO_mat(s,:) / sum(time_in_bin(s,:),2,'omitnan');
    end
    
end

%% Normalize along a dimension if desired
if pow_freqSO_norm(1) == true
    SO_mat = SO_mat ./ sum(SO_mat,1);
end

if pow_freqSO_norm(2) == true
    SO_mat = SO_mat ./ sum(SO_mat,2);
end

%% Plot
if plot_flag == true
   figure;
   imagesc(SO_cbins, freq_cbins, SO_mat')
   axis xy
   colormap parula
   climscale([],[],false);
   colorbar;
   xlabel('SO Power (normalized)');
   ylabel('Frequency (Hz)');
end

end


