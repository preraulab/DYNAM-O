function [SOpow, SOphase, freq_bins, SOpow_bins, SOphase_bins, stage_props, total_times, peak_times, peak_freqs] = ...
             watershed2SOpowphase(EEG, Fs, t, stages, watershed_peaks, watershed_fields, watershed_names, peaks_dur_minmax, peaks_bw_minmax, ...
             peaks_freq_minmax, artifact_detect, artifact_filters, flip_phase, SO_stage_select, time_in_bin, freq_df, window_size, window_step_size,...
             SO_norm, lightsonoff, SO_ploton, SO_plotsave)
%WATERSHED2SOPOWPHASE 
%
% Inputs:
%   EEG: 1xN double - signal data
%   Fs: integer - sampling frequency (Hz)
%   t: 1xN double - timepoint for each sample in EEG (seconds)
%   stages: 1xN vector - sleep stage scoring for each sample in EEG (0=Unidentified, 1=NREM3,
%           2=NREM2, 3=NREM1, 4=REM, 5=WAKE)
%   watershed_peaks: Px79 matrix - peaks_matr output from peaksWShedStatsFromData function
%   watershed_fields: 1X35 double - matr_fields output from peaksWShedStatsFromData function
%   watershed_names: 1x35 cell - matr_names output from peaksWShedStatsFromData function
%   peaks_dur_minmax: 1x2 double - bounds of peak durations to include (seconds). Default = [0.5,5]
%   peaks_bw_minmax: 1x2 double - bounds of peak bandwidth to include (seconds). Default = [2, 15]
%   peaks_freq_minmax: 1x2 double - bounds of peak frequencies to include (seconds). Default = [0, 40]
%   artifact_detect: logical - run artifact detection and change artifact stages to stage 0. Default = True
%   artifact_filters: structure - precomputed filters for artifact detection. Must contain fields "hpFilt_high", 
%                     "hpFilt_broad", and "detrend_filt", all must be digitalFilters. Default = filters will 
%                     be computed internally using designfilt if left blank and artifact_detect==true. 
%   flip_phase: logical - negate EEG data in order to flip the phase of the signal. Default = false. 
%   SO_stage_select: 1xs vector - indicate sleep stages to include in the SO power and phase analyses 
%                    (0=Unidentified, 1=NREM3, 2=NREM2, 3=NREM1, 4=REM, 5=WAKE). Default = [1:4]. 
%   time_in_bin: double - amount of sleep time (minutes) necessary in a particular SO-power bin for the 
%                bin to be computed, else the column will ne NaNs. Default = 1.
%   freq_df: 1x2 double - bin/window size for frequency axis in Hz for SO-power and SO-phase 
%            analyses respectively. Default = [0.1, 0.1]
%   window_size: 1x2 double - bin/window size for power and phase (radians) axes respectively. Note that 
%                the units of the power axis will change based on the normalization method chosen (SO_norm). 
%                The default window size for power assumes any percent normalizaiton method is being used. 
%                Default = [0.05, 1].
%   window_step_size: 1x2 double - bin/window step size for power and phase (radians) axes respectively. 
%                     Note that the units of the power axis will change based on the normalization method 
%                     chosen (SO_norm). The default window size for power assumes any percent normalizaiton 
%                     method is being used. Default = [0.01, 0.05]].
%   SO_norm: char - normalization method for SO-power. Accepted values: 'percent', 'percentile', 
%                   'percentsleep', 'percentnoartifact', 'shift', 'absolute'. Default = 'percentnoartifact'
%   lightsonoff: logical - will cut the data 5 min before sleep onset, and 5min after in order to exclude wake 
%                from normalization calculation. Use if data contains wake periods before and after night of sleep. 
%                Default = false
%   SO_ploton: logical - plot resulting SO-power and SO-phase figures
%   SO_plotsave: logical or char - save resulting SO-power and SO-phase figures to png files. Input true will 
%                result in files being saved to .SO/ directory. Input a char filepath to save to specified 
%                directory. Default = false. 
%
% Outputs:
%   SOpow: nbins_power x nbins_freq matrix - 2D histogram/heatmap of SO-power (peaks/min) 
%   SOphase: nbins_phase x nbins_freq matrix - 2D histogram/heatmap of SO-phase (peaks/min normalized per row)
%   freq_bins: 1xF double - bin centers of frequency bins in SOpow and SOphase (Hz)
%   SOpow_bins: 1xB double - bin centers of power bins in SOpow (units depend on normalization method chosen)
%   SOphase_bins:1xC double - bin centers of phase bins in SOpow (radians)
%   stage_props: Bx5 vector - number of minutes spent in each power bin (row) for each sleep stage (column)
%   total_times: double - total minutes in sleep stages 1-5
%   peak_times: timestamps for each non-noise peak from watershed
%   peak_freqs: centroid frequency for each non-noise peak from watershed
%
%%%************************************************************************************%%%

%% Deal with Inputs

assert(nargin >= 7, '7 input arguments required (EEG, Fs, t, stages, watershed_peaks, watershed_fields, watershed_names)')

if nargin < 8 || isempty(peaks_dur_minmax)
    peaks_dur_minmax = [0.5,5];
end

if nargin < 9 || isempty(peaks_bw_minmax)
    peaks_bw_minmax = [2, 15];
end

if nargin < 10 || isempty(peaks_freq_minmax)
    peaks_freq_minmax = [0, 40];
end

if nargin < 11 || isempty(artifact_detect)
    artifact_detect = true;
end

if (nargin < 12 || isempty(artifact_filters)) && artifact_detect
    artifact_filters.hpFilt_high = designfilt('highpassiir','FilterOrder',4, ...
                                              'PassbandFrequency',35,'PassbandRipple',0.2, ...
                                               'SampleRate',Fs);
    artifact_filters.hpFilt_broad = designfilt('highpassiir','FilterOrder',4, ...
                                                'PassbandFrequency',2,'PassbandRipple',0.2, ...
                                                'SampleRate',Fs);
    artifact_filters.detrend_filt = designfilt('highpassiir','FilterOrder',4, ...
                                                'PassbandFrequency',0.001,'PassbandRipple',0.2, ...
                                                'SampleRate',Fs);
elseif ~artifact_detect
    artifact_filters = [];
end

if nargin < 13 || isempty(flip_phase)
    flip_phase = false;
end

if nargin < 14 || isempty(SO_stage_select)
    SO_stage_select = [1:4];
end

if nargin < 15 || isempty(time_in_bin)
    time_in_bin = 1; % minutes
end

if nargin <16 || isempty(freq_df)
    freq_df = [0.1, 0.1]; 
end

if nargin <17 || isempty(window_size)
    window_size = [0.05, 1];
end

if nargin<18 || isempty(window_step_size)
    window_step_size = [0.01, 0.05];
end

if nargin < 17 || isempty(SO_norm)
    SO_norm = 'percentnoartifact';
end

if nargin < 18 || isempty(lightsonoff)
    lightsonoff = true;
end

if nargin < 18 || isempty(SO_ploton)
    SO_ploton = true;
end

if nargin < 19 || isempty(SO_plotsave) || ~SO_ploton || ~SO_plotsave
    SO_plotsave = [];
elseif SO_plotsave == true
    SO_plotsave = './SO';
end

%% Get Peak Times and Freqs, Downselect valid peaks 

if isa(watershed_peaks, 'uint8') % make sure peaks data are not still in bytestream
    watershed_peaks =  getArrayFromByteStream(watershed_peaks); % convert from bytestream
end


[~, ~, times_freqs] = filterpeaks_watershed(watershed_peaks, watershed_fields, watershed_names, ...
                                            peaks_dur_minmax, peaks_bw_minmax, peaks_freq_minmax);

clear watershed_peaks  % free up memory

peak_times = times_freqs(:,1);
peak_freqs = times_freqs(:,2);

%% artifact detection 
artifacts = detect_artifacts(EEG, Fs, 'std', 3.5, 35, 3.5, 2, 2, false, false, false,...
                             artifact_filters.hpFilt_high, artifact_filters.hpFilt_broad,...
                             artifact_filters.detrend_filt);
stages(artifacts) = 0; % mark artifacts as "Unidentified" % originally 5

%% Compute SO pow and phase 

% Set up stage_struct structure
stage_struct.stage = stages';
stage_struct.time = t;
stage_struct.pick_t = ismember(stages, SO_stage_select);
stage_struct.pick_t = stage_struct.pick_t;

% Find peaks that occur during selected stages only
peak_stages = interp1(t, stages, peak_times, 'nearest');
peak_inds_use = ismember(peak_stages, SO_stage_select);

% Calc SO pow
[SOpow, SOpow_bins, freq_bins, ~, stage_props, total_times, ~] = ...
        swFeatHist(EEG, Fs, peak_freqs, peak_times, peak_inds_use, stage_struct, ...
        'power', [], SO_norm, [], SO_stage_select, time_in_bin, freq_df(1), window_size(1), window_step_size(1), [], [], lightsonoff, SO_ploton); 

if ~isempty(SO_plotsave)
    print(gcf, [SO_plotsave, '_pow.png'], '-dpng', '-r300')
end

% Calc SO phase
if flip_phase
    EEG = -EEG;
end

[SOphase, SOphase_bins, ~ , ~, ~, ~, ~] = ...
    swFeatHist(EEG, Fs, peak_freqs, peak_times, peak_inds_use, stage_struct, ...
    'phase', [], 'perSubj', [], SO_stage_select, time_in_bin, freq_df(2), window_size(2), window_step_size(2), [], [], lightsonoff, SO_ploton); 

if ~isempty(SO_plotsave)
    print(gcf, [SO_plotsave, '_phase.png'], '-dpng', '-r300')
end
    
end

