function [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOpower_norm, peak_selection_inds, SOpower_norm, ptile, SOpow_times] = SOpowerHistogram(varargin)
% % SOPOWERHISTOGRAM computes slow-oscillation power matrix
% Usage:
%   [SO_mat, freq_cbins, SO_cbins, time_in_bin, prop_in_bin, peak_SOpower_norm, peak_selection_inds] = ...
%                           SOpowerHistogram(EEG, Fs, TFpeak_freqs, TFpeak_times, freq_range, freq_binsizestep, ...
%                                        SO_range, SO_binsizestep, SOfreq_range, artifacts, ...
%                                        stage_exclude, t_data, norm_method, min_time_in_bin, lightsonoff_times, ...
%                                        pow_freqSO_norm, rate_flag, smooth_flag, plot_flag)
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
%       SO_range: 1x2 double - min and max SO power values to consider in SO phase analysis. 
%                 Default calculated using min and max of SO power
%       SO_binsizestep: 1x2 double - [size, step] SO phase bin size and step for SO phase axis 
%                            of histogram. Units are radians. Default
%                            size is (SO_range(2)-SOrange(1))/5, default step is
%                            (SO_range(2)-SOrange(1))/100
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation". 
%                     Default = [0.3, 1.5]
%       artifacts: 1xN logical - marks each timestep of EEG as artifact or non-artifact. Default = all false. 
%       stage_exclude: 1xN logical - marks which timestep of EEG should be excluded due to being in an 
%                      undesired stage. Default = all false.
%       t_data: 1xN double - times for each EEG sample. Default = (0:length(EEG)-1)/Fs
%       norm_method: char - normalization method for SO-power. Options: 'p5shift'(default), 'percent', 'proportion', 'none'.
%       min_time_in_bin: numerical - time (minutes) required in each SO power bin to include 
%                              in SO power analysis. Otherwise all values in that SO power bin will 
%                              be NaN. Default = 1.
%       time_range: 1x2 double - min and max times for which to include TFpeaks. Also used to normalize 
%                   SO power. Default = [t_data(1), t_data(end)] 
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
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%% Parse input

p = inputParser;
addRequired(p, 'EEG', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'TFpeak_freqs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p, 'TFpeak_times', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p, 'freq_range', [0,40], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'freq_binsizestep', [1, 0.2], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_range', [], @(x) validateattributes(x,{'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'SO_binsizestep', [], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan', 'positive'}));
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'artifacts', [], @(x) validateattributes(x, {'logical', 'vector'},{}));
addOptional(p, 'stage_exclude', [], @(x) validateattributes(x, {'logical', 'vector'},{}));
addOptional(p, 't_data', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'norm_method', 'p5shift', @(x) validateattributes(x, {'char', 'numeric'},{}));
addOptional(p, 'min_time_in_bin', 1, @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonnan', 'nonnegative','integer'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'pow_freqSO_norm', [false, false], @(x) validateattributes(x,{'logical', 'vector'},{}));
addOptional(p, 'rate_flag', true, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'smooth_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'plot_flag', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'proportion_freqrange', [0.3, 30], @(x) validateattributes(x, {'numeric','vector'},{'real','finite','nonnan'}));
addOptional(p, 'verbose', true, @(x) validateattributes(x,{'logical'},{}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if isempty(artifacts) %#ok<*NODEF>
    artifacts = false(size(EEG,2),1);
else
    assert(length(artifacts) == size(EEG,2),'artifacts must be the same length as EEG');
end

if isempty(stage_exclude)
    stage_exclude = false(size(EEG,2),1);
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

%% Replace artifact timepoints with NaNs
nanEEG = EEG;
nanEEG(artifacts) = nan;

%% Compute SO power
[SOpower, SOpow_times] = computeMTSpectPower(nanEEG, Fs, 'freq_range', SO_freqrange);
SOpow_times = SOpow_times + t_data(1); % adjust the time axis to t_data
SOpow_times_step = SOpow_times(2) - SOpow_times(1);

% Exclude outlier SOpower that usually reflect artifacts
SOpower(abs(nanzscore(SOpower)) >= 3) = nan;

% Remove single time points sandwiched between nan values 
last_isnan = [0; isnan(SOpower(1:end-1))];
next_isnan = [isnan(SOpower(2:end)); 0];
SOpower(last_isnan & next_isnan) = nan;

% Normalize SO power
if isnumeric(norm_method)
    % Allow numeric input to set the percentile used in the 'shift' method
    shift_ptile = norm_method;
    norm_method = 'shift';
else
    shift_ptile = 5;
end
switch norm_method 
    case {'proportion', 'normalized'}
        [proppower, ~] = compute_mtspect_power(nanEEG, Fs, 'freq_range', [proportion_freqrange(1), proportion_freqrange(2)]);
        SOpower_norm = db2pow(SOpower)./db2pow(proppower);
        ptile = [];
    
    case {'percentile', 'percent', '%', '%SOP'}
        low_val =  1;
        high_val =  99;
        ptile = prctile(SOpower(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), [low_val, high_val]);
        SOpower_norm = SOpower-ptile(1);
        SOpower_norm = SOpower_norm/(ptile(2) - ptile(1));
        
    case {'shift', 'p5shift'}
        ptile = prctile(SOpower(SOpow_times>=time_range(1) & SOpow_times<=time_range(2)), shift_ptile);
        SOpower_norm = SOpower-ptile(1);

    case {'absolute', 'none'}
        SOpower_norm = SOpower;
        ptile = [];
        
    otherwise
        error(['Normalization method "', norm_method, '" not recognized']);
end

%% Get SOpower at each peak time
peak_SOpower_norm = interp1(SOpow_times, SOpower_norm, TFpeak_times, 'nearest');

%% Get valid peak indices
% Exclude peaks during unwanted stages, artifacts, and outside time range
stage_inds_peaks = logical(interp1(t_data, double(~stage_exclude), TFpeak_times, 'nearest')); 
artifact_inds_peaks = logical(interp1(t_data, double(artifacts), TFpeak_times, 'nearest'));
timerange_inds_peaks = (TFpeak_times >= time_range(1)) & (TFpeak_times <= time_range(2));

peak_selection_inds = stage_inds_peaks & ~artifact_inds_peaks & timerange_inds_peaks & ~isnan(peak_SOpower_norm);

%% Get valid SOpower indices
% Exclude unwanted stages, artifacts, and outside time range
SOpower_stages_valid = logical(interp1(t_data, double(~stage_exclude), SOpow_times, 'nearest'));
SOpower_artifact_valid = ~isnan(SOpower_norm)';
SOpower_times_valid = (SOpow_times>=time_range(1) & SOpow_times<=time_range(2));

SOpower_valid = SOpower_stages_valid & SOpower_artifact_valid & SOpower_times_valid;
SOpower_valid_allstages = SOpower_artifact_valid & SOpower_times_valid;

%% Compute the SO power historgram
% Get frequency bins
[freq_bin_edges, freq_cbins] = create_bins(freq_range, freq_binsizestep(1), freq_binsizestep(2), 'partial');
num_freqbins = length(freq_cbins);

% Get SO power bins
if isempty(SO_range)
    SO_range(1) = min(SOpower_norm);
    SO_range(2) = max(SOpower_norm);
end
if isempty(SO_binsizestep)
    SO_binsizestep(1) = (SO_range(2) - SO_range(1)) / 5;
    SO_binsizestep(2) = (SO_range(2) - SO_range(1)) / 100;
end
[SO_bin_edges, SO_cbins] = create_bins(SO_range, SO_binsizestep(1), SO_binsizestep(2), 'partial');
num_SObins = length(SO_cbins);

% Display SOPH settings
if verbose
    disp(['  SO-Power Histogram Settings' , newline, ...
          '    Normalization Method: ', num2str(norm_method), newline, ...
          '    Frequency Window Size: ' num2str(freq_binsizestep(1)) ' Hz, Window Step: ' num2str(freq_binsizestep(2)) ' Hz', newline,...
          '    Frequency Range: ', num2str(freq_range(1)) '-' num2str(freq_range(2)) ' Hz', newline,...
          '    SO-Power Window Size: ' num2str(SO_binsizestep(1)) ', Window Step: ' num2str(SO_binsizestep(2)), newline,...
          '    SO-Power Range: ', num2str(SO_range(1)), '-', num2str(SO_range(2)),  newline,...
          '    Minimum time required in each SO-Power bin: ', num2str(min_time_in_bin), 'min', newline]);
end

% Intialize SOpow * freq matrix
SO_mat = nan(num_SObins, num_freqbins);

% Initialize time in bin
time_in_bin = zeros(num_SObins,1);
prop_in_bin = zeros(num_SObins,1);

for s = 1:num_SObins
    
    % Get indices of SOpow that occur in this SOpow bin
    TIB_inds = (SOpower_norm >= SO_bin_edges(1,s)) & (SOpower_norm < SO_bin_edges(2,s));
    
    % Get indices of TFpeaks that occur in this SOpow bin
    SO_inds = (peak_SOpower_norm >= SO_bin_edges(1,s)) & (peak_SOpower_norm < SO_bin_edges(2,s));
    
    % Get time in bin (min) and proportion of time in bin
    time_in_bin(s) = (sum(TIB_inds & SOpower_valid') * SOpow_times_step) / 60;
    time_in_bin_allstages = (sum(TIB_inds & SOpower_valid_allstages') * SOpow_times_step) / 60;
    prop_in_bin(s) = time_in_bin(s) / time_in_bin_allstages;
    
    % if less than threshold time in SO bin, whole column of SO power hist should be nan
    if time_in_bin(s) < min_time_in_bin
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
    
    if smooth_flag
        SO_mat(s,:) = smooth(SO_mat(s,:));
    end 
    
    if rate_flag
        SO_mat(s,:) = SO_mat(s,:) / time_in_bin(s);
    end
    
end

%% Normalize along a dimension if desired
if pow_freqSO_norm(1)
    SO_mat = SO_mat ./ sum(SO_mat,1);
end

if pow_freqSO_norm(2)
    SO_mat = SO_mat ./ sum(SO_mat,2);
end

%% Plot
if plot_flag
   figure;
   imagesc(SO_cbins, freq_cbins, SO_mat')
   axis xy
   colormap(gouldian)
   climscale([],[],false);
   colorbar;
   xlabel('SO Power (normalized)');
   ylabel('Frequency (Hz)');
end

end


