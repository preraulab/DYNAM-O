function [ spindle_table, mt_spect, fpeak_proms, fpeak_properties, tpeak_properties, noise_peak_times, lowbw_TFpeaks, fh ] = TF_peak_detection(EEG, Fs, sleep_stages, varargin)
% TF_PEAK_DETECTION  Detect time-frequency peaks in EEG data
%
%   Usage:
%       [spindle_table, mt_spect, fpeak_proms, fpeak_properties, tpeak_properties, noise_peak_times, lowbw_TFpeaks, fh] = TF_peak_detection(EEG, Fs, sleep_stages, 'Name1', Value1, 'Name2', Value2, ...)
%
%   Input:
%       EEG: <number of samples> x 1 vector - EEG data
%       Fs: double - sampling frequency in Hz
%       sleep_stages: <number of samples> x 2 matrix - sleep stage transitions
%       'detection_stages': 1xN vector - stages for peak detection (default: [1 2 3])
%       'to_plot': boolean - plot results (default: false)
%       'verbose': boolean - display verbose output (default: true)
%       'spindle_freq_range': 1x2 vector - spindle frequency range (default: [0, Fs/2])
%       'extract_property': boolean - extract properties only (default: false)
%       'signal_selection_routine': string - signal selection routine ('post2021' or 'sleep2021', default: 'post2021')
%       'artifact_detect': boolean / boolean vector - flag to detect artifacts or a boolean vector indicating artifact time points (default: true)
%       'artifact_filters': struct - artifact filter parameters (default: empty struct)
%       'use_volume': boolean - use volume for signal selection (default: false)
%       'peak_freq_range': 1x2 vector - frequency range for peak detection (default: [9 17])
%       'findpeaks_freq_range': 1x2 vector - larger frequency range for finding peaks to identify peaks outside the peak_freq_range (default: determined from 'peak_freq_range')
%       'in_db': boolean - peak detection in decibels (default: false)
%       'smooth_Hz': double - smoothing in frequency domain (default: 0)
%
%   Output:
%       spindle_table: table - detected spindle peaks information
%       mt_spect: struct - multitaper spectrogram information
%       fpeak_proms: vector - prominence values of frequency peaks
%       fpeak_properties: struct - properties of frequency peaks
%       tpeak_properties: struct - properties of time peaks
%       noise_peak_times: vector - times of detected noise peaks
%       lowbw_TFpeaks: vector - low bandwidth time-frequency peaks
%       fh: figure handle - handle to the generated figure
%
%   Details:
%   This function detects time-frequency peaks in EEG data using a combination of techniques
%   including multitaper spectrogram computation, artifact detection, frequency peak detection,
%   time peak detection, and signal selection routines.
%
%   Example:
%   % Define input variables
%   EEG = ...; % EEG data vector
%   Fs = ...; % Sampling frequency
%   sleep_stages = ...; % Sleep stage transitions
%
%   % Call the TF_peak_detection function with optional parameters
%   [spindle_table, mt_spect, fpeak_proms, fpeak_properties, tpeak_properties, noise_peak_times, lowbw_TFpeaks, fh] = TF_peak_detection(EEG, Fs, sleep_stages, ...
%       'detection_stages', [1 2 3], 'to_plot', true, 'verbose', true, 'spindle_freq_range', [10 16], ...);
%
%  Latest version of TF_peak_detection using signal/noise separation routines developed after SLEEP 2021 publication ***
%  Last edit: Alex He 09/29/2023
%
% Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

TF_peak_tic = tic;

%% Parse input variables
[ input_arguments, input_flags ] = TF_peak_inputparse(EEG,Fs,sleep_stages,varargin{:}); %#ok<ASGLU>
eval(['[', sprintf('%s ', input_flags{:}), '] = deal(input_arguments{:});']);

%% Multitaper spectrogram computation
disp('Creating the spectrogram by using the multitaper_spectrogram function...');
[ spect, stimes, sfreqs ] = compute_multitaper(EEG, Fs, MT_freq_max, MT_taper, MT_window, MT_min_NFFT, MT_detrend, MT_weighting, verbose);

%% Artifact detection and valid time points selection
if artifact_detect == true
    disp('Detecting Artifacts and setting up indices...');
else
    disp('Setting up indices...');
end
[ detection_inds, ~, stages_in_stimes ] = select_time_indices(sleep_stages, EEG, Fs, stimes, [], detection_stages, artifact_detect, artifact_filters);

%% TF Peak Detection - main algorithm
disp('Finding frequency peaks...');
[ fpeak_proms, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, spectrogram_used ] = find_frequency_peaks(spect,stimes,sfreqs,...
    'valid_time_inds',detection_inds, 'peak_freq_range',peak_freq_range, 'findpeaks_freq_range',findpeaks_freq_range,...
    'in_db',in_db, 'smooth_Hz',smooth_Hz, 'verbose', verbose, 'findpeaks_version', 'linear');

disp('Finding time peaks...');
[ fpeak_proms, tpeak_proms, tpeak_times, tpeak_durations, tpeak_center_times,...
    tpeak_central_frequencies, tpeak_bandwidths, tpeak_bandwidth_bounds]...
    = find_time_peaks(fpeak_proms, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, stimes,...
    'valid_time_inds', detection_inds, 'min_peak_width_sec',min_peak_width_sec, 'min_peak_distance_sec',min_peak_distance_sec, 'smooth_sec',smooth_sec);

% create a struct to output multitaper spectrogram info (added on Jan 8th 2021)
mt_spect = struct;
mt_spect.spect = spectrogram_used;
mt_spect.stimes = stimes;
mt_spect.sfreqs = sfreqs;
mt_spect.stages_in_stimes = stages_in_stimes;

% create a struct to output tpeak properties (added on July 18th 2020)
fpeak_properties = struct;
fpeak_properties.freqs = fpeak_freqs;
fpeak_properties.bandwidths = fpeak_bandwidths;
fpeak_properties.bandwidth_bounds = fpeak_bandwidth_bounds;

tpeak_properties = struct;
tpeak_properties.proms = tpeak_proms;
tpeak_properties.times = tpeak_times;
tpeak_properties.durations = tpeak_durations;
tpeak_properties.center_times = tpeak_center_times;
tpeak_properties.central_frequencies = tpeak_central_frequencies;
tpeak_properties.bandwidths = tpeak_bandwidths;
tpeak_properties.bandwidth_bounds = tpeak_bandwidth_bounds;

[~, stage_index] = ismember(tpeak_center_times, stimes);
temp_stages = stages_in_stimes(stage_index)';
canonical_stages = categorical(zeros(size(temp_stages)));
canonical_stages(temp_stages==1) = 'Stage3';
canonical_stages(temp_stages==2) = 'Stage2';
canonical_stages(temp_stages==3) = 'Stage1';
canonical_stages(temp_stages==4) = 'REM';
canonical_stages(temp_stages==5) = 'Wake';
canonical_stages(temp_stages==0) = 'Undefined';
tpeak_properties.stages = canonical_stages;

if extract_property || strcmp(signal_selection_routine, 'post2021')
    spindle_table = [];
    noise_peak_times = [];
    lowbw_TFpeaks = [];
    fh = [];
    if extract_property; return; end % exit if only extracting properties
end

disp('Selecting TF peaks...');
switch signal_selection_routine
    case 'sleep2021'
        % prepare for kmeans clustering
        if use_volume
            % using log volume rather than log prominence - more robust?
            candidate_signals = log(tpeak_proms.*tpeak_durations.*tpeak_bandwidths);
        else
            % using log prominence values
            candidate_signals = log(tpeak_proms);
        end
        % calculate spectral resolution
        spectral_resol = MT_taper(1)*2 / MT_window(1);
        if bandwidth_cut % with or without bandwidth cutoff
            bandwidth_data = tpeak_bandwidths;
        else
            bandwidth_data = [];
        end
        [ TFpeak_times, noise_peak_times, clustering_idx, clustering_prom_order, lowbw_TFpeaks ] = ...
            TF_peak_selection(candidate_signals, tpeak_times, 'detection_method',detection_method,...
            'bandwidth_data',bandwidth_data, 'spectral_resol',spectral_resol, 'num_clusters',num_clusters,...
            'prominence_column', 1, 'threshold_percentile',threshold_percentile, 'verbose', verbose);
        
    case 'post2021' % (added on April 14th 2023)
        % identify signal TF peaks using two separate kmeans clustering
        clustering_idx = select_signal_TFpeaks(tpeak_properties, false);
        clustering_prom_order = [1, 0];
        TFpeak_times = tpeak_times(clustering_idx, :);
        
        % use event centroids to update tpeak_center_times and
        % tpeak_central_frequencies for creating spindle_table.
        % Keep the tpeak_properties structure unchanged
        [tpeak_center_times, tpeak_central_frequencies] = extract_event_centroid(mt_spect, tpeak_properties);
        
end

tpeak_properties.clustering_order = clustering_prom_order;
tpeak_properties.clustering_idx = clustering_idx;

%% Create the output table
spindle_table = create_output_tbl(stimes, stages_in_stimes, TFpeak_times, clustering_idx, clustering_prom_order, tpeak_center_times, tpeak_central_frequencies, tpeak_bandwidth_bounds, tpeak_proms);

%% Post processing of spindle_table
% filter to spindle frequency range (added on July 18th 2020)
% valid_spindles = spindle_table.Freq_Low >= spindle_freq_range(1) & spindle_table.Freq_High <= spindle_freq_range(2);
valid_spindles = spindle_table.Freq_Central >= spindle_freq_range(1) & spindle_table.Freq_Central <= spindle_freq_range(2);
spindle_table(~valid_spindles,:) = [];
if verbose
    disp(['Number of spindles dropped due to exceeding bandwidth bounds: ', num2str(sum(~valid_spindles))])
end

%% Plot the spectrogram with TF peaks
if to_plot
    fh = TF_peak_plot(spect, stimes, sfreqs, stages_in_stimes, spindle_table);
else
    fh = [];
end

%%
% Completed!
if verbose
    disp('Time taken in running TF_peak_detection:')
    toc(TF_peak_tic)
end

end

%%%%%%%%%%%%%%%%%%%%%
% HELPER FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%

function [ input_arguments, input_flags ] = TF_peak_inputparse(EEG,Fs,sleep_stages,varargin)
%% Inputs using input parser
p = inputParser;

% TF_peak_detection wrapper parameters
check_sleep_stages = @(x) size(x,2)==2 & isnumeric(x);
default_detection_stages = [1 2 3]; % stages: 1xN vector of stage values (0:Undefined, 5:Wake, 4:REM, 3:N1, 2:N2, 1:N3)
check_detection_stages = @(x) length(unique(x))==length(x) & all(x<=5);
default_to_plot = false;
default_verbose = true;
default_spindle_freq_range = [0, Fs/2];
default_extract_property = false;
default_signal_selection_routine = 'post2021';
valid_signal_selection_routine = {'post2021','sleep2021'};
default_artifact_detect = true;
default_artifact_filters = struct;
default_artifact_filters.hpFilt_high = [];
default_artifact_filters.hpFilt_broad = [];
default_use_volume = false;

% find frequency peaks parameters
default_peak_freq_range = [9 17];
default_findpeaks_freq_range = [ ];
check_freq_range = @(x) isempty(x) | ((size(x,1)*size(x,2)==2) & (x(2)>=x(1)) & (x(1)>=0) & (x(2)<=Fs/2));
default_in_db = false;
default_smooth_Hz = 0; %Hz
check_smooth_Hz = @(x) isnumeric(x) & (x>=0) & (x<=Fs/2);

% find time peaks parameters
default_smooth_sec = 0.3; %sec
default_min_peak_width_sec = []; %sec - SLEEP 2021 used 0.3
default_min_peak_distance_sec = 0; %sec

% TF_peak_selection parameters
default_detection_method = 'kmeans';
valid_detection_method = {'kmeans','threshold'};
default_bandwidth_cut = true;
default_num_clusters = 2 ;
default_threshold_percentile = 75;
check_threshold_percentile = @(x) (isnumeric(x)) & (x<=100);

% Multitaper parameters
default_MT_freq_max = 30;
default_MT_taper = [2 3];
default_MT_window = [1 0.05];
check_MT_vect = @(x) (size(x,1)*size(x,2))==2;
default_MT_dsfreqs = 0.1; %Hz
default_MT_min_NFFT = [];
default_MT_detrend = 'constant';
valid_MT_detrend = {'linear','constant','off'};
default_MT_weighting = 'unity';
valid_MT_weighting = {'unity','eigen','adapt'};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Construct parser
addRequired(p,'EEG', @isvector);
addRequired(p,'Fs', @isnumeric);
addRequired(p,'sleep_stages', check_sleep_stages);
% TF_peak_detection wrapper parameters
addParameter(p,'detection_stages',default_detection_stages, check_detection_stages);
addParameter(p,'to_plot',default_to_plot, @islogical);
addParameter(p,'verbose',default_verbose, @islogical);
addParameter(p,'spindle_freq_range',default_spindle_freq_range, check_freq_range);
addParameter(p,'extract_property',default_extract_property, @islogical);
addParameter(p,'signal_selection_routine',default_signal_selection_routine, @ischar);
addParameter(p,'artifact_detect',default_artifact_detect, @islogical);
addParameter(p,'artifact_filters',default_artifact_filters, @isstruct);
addParameter(p,'use_volume',default_use_volume, @islogical);
% find frequency peaks parameters
addParameter(p,'peak_freq_range',default_peak_freq_range, check_freq_range);
addParameter(p,'findpeaks_freq_range',default_findpeaks_freq_range, check_freq_range);
addParameter(p,'in_db',default_in_db, @islogical);
addParameter(p,'smooth_Hz',default_smooth_Hz, check_smooth_Hz);
% find time peaks parameters
addOptional(p,'smooth_sec',default_smooth_sec, @isnumeric);
addOptional(p,'min_peak_width_sec',default_min_peak_width_sec, @isnumeric);
addOptional(p,'min_peak_distance_sec',default_min_peak_distance_sec, @isnumeric);
% TF_peak_selection parameters
addParameter(p,'detection_method',default_detection_method, @ischar);
addParameter(p,'bandwidth_cut',default_bandwidth_cut, @logical);
addParameter(p,'num_clusters',default_num_clusters, @isinteger);
addParameter(p,'threshold_percentile',default_threshold_percentile, check_threshold_percentile);
% Multitaper parameters
addParameter(p,'MT_freq_max',default_MT_freq_max, @isnumeric);
addParameter(p,'MT_taper',default_MT_taper, check_MT_vect);
addParameter(p,'MT_window',default_MT_window, check_MT_vect);
addParameter(p,'MT_dsfreqs',default_MT_dsfreqs, @isnumeric);
addParameter(p,'MT_min_NFFT',default_MT_min_NFFT, @isnumeric);
addParameter(p,'MT_detrend',default_MT_detrend, @ischar);
addParameter(p,'MT_weighting',default_MT_weighting, @ischar);

% now parse the input variables
parse(p,EEG,Fs,sleep_stages,varargin{:});

% instantiate outputs
input_arguments = struct2cell(p.Results);
input_flags = fieldnames(p.Results);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Additional variable processing and modification of outputs
% handle the validatestring inputs
signal_selection_routine_index = find(cellfun(@(x) strcmp(x, 'signal_selection_routine'), input_flags)==1);
input_arguments{signal_selection_routine_index} = validatestring(input_arguments{signal_selection_routine_index}, valid_signal_selection_routine);
detection_method_index = find(cellfun(@(x) strcmp(x, 'detection_method'), input_flags)==1);
input_arguments{detection_method_index} = validatestring(input_arguments{detection_method_index}, valid_detection_method);
MT_detrend_index = find(cellfun(@(x) strcmp(x, 'MT_detrend'), input_flags)==1);
input_arguments{MT_detrend_index} = validatestring(input_arguments{MT_detrend_index}, valid_MT_detrend);
MT_weighting_index = find(cellfun(@(x) strcmp(x, 'MT_weighting'), input_flags)==1);
input_arguments{MT_weighting_index} = validatestring(input_arguments{MT_weighting_index}, valid_MT_weighting);

% Update min_peak_width_sec based on the signal_selection_routine
min_peak_width_sec_index = find(cellfun(@(x) strcmp(x, 'min_peak_width_sec'), input_flags)==1);
if isempty(input_arguments{min_peak_width_sec_index})
    switch input_arguments{signal_selection_routine_index}
        case 'sleep2021'
            input_arguments{min_peak_width_sec_index} = 0.3; %sec
        case 'post2021'
            input_arguments{min_peak_width_sec_index} = 0; %sec
    end
end

% set the default MT_min_NFFT
MT_min_NFFT_index = find(cellfun(@(x) strcmp(x, 'MT_min_NFFT'), input_flags)==1);
if isempty(input_arguments{MT_min_NFFT_index})
    MT_dsfreqs = input_arguments{find(cellfun(@(x) strcmp(x, 'MT_dsfreqs'), input_flags)==1)};
    default_MT_min_NFFT = 2^nextpow2(Fs/MT_dsfreqs);
    input_arguments{MT_min_NFFT_index} = default_MT_min_NFFT;
end

% validity check
threshold_percentile_index = find(cellfun(@(x) strcmp(x, 'threshold_percentile'), input_flags)==1);
if input_arguments{threshold_percentile_index}<1 && strcmp(input_arguments{detection_method_index}, 'threshold') %#ok<*FNDSB>
    warning('The current threshold percentile is <1. If this was intentional disregard this message. Otherwise use a percentile between 1 and 100.');
end

% set the default findpeaks_freq_range based off peak_freq_range and MTS spectral resolution
% NOTE: the purpose of this procedure is to make sure we understand the
% difference between a peak that falls outside the peak_freq_range and a
% peak with its max at the edge of peak_freq_range
findpeaks_freq_range_index = find(cellfun(@(x) strcmp(x, 'findpeaks_freq_range'), input_flags)==1);
if isempty(input_arguments{findpeaks_freq_range_index})
    peak_freq_range = input_arguments{find(cellfun(@(x) strcmp(x, 'peak_freq_range'), input_flags)==1)};
    MT_taper = input_arguments{find(cellfun(@(x) strcmp(x, 'MT_taper'), input_flags)==1)};
    MT_window = input_arguments{find(cellfun(@(x) strcmp(x, 'MT_window'), input_flags)==1)};
    Fs = input_arguments{find(cellfun(@(x) strcmp(x, 'Fs'), input_flags)==1)};
    spectral_resol = MT_taper(1)*2 / MT_window(1);
    default_findpeaks_freq_range = [max(0, peak_freq_range(1)-spectral_resol), min(Fs/2, peak_freq_range(2)+spectral_resol)];
    input_arguments{findpeaks_freq_range_index} = default_findpeaks_freq_range;
end

% smoothing in peaks shouldn't be wider than frequency range
smooth_Hz_index = find(cellfun(@(x) strcmp(x, 'smooth_Hz'), input_flags)==1);
peak_freq_range_index = find(cellfun(@(x) strcmp(x, 'peak_freq_range'), input_flags)==1);
if input_arguments{smooth_Hz_index} > 0
    warning('Direct smoothing in frequency domain is not recommended. Consider using multitaper parameters with wider spectral resolution to achieve spectral smoothing.')
end
assert(input_arguments{smooth_Hz_index} <= diff(input_arguments{peak_freq_range_index}), 'Smoothing is wider than the frequency range for detecting frequency peaks.')

end

function [ spect,stimes,sfreqs ] = compute_multitaper(EEG, Fs, MT_freq_max, MT_taper, MT_window, MT_min_NFFT, MT_detrend, MT_weighting, verbose)
spectrogram_parameters.frequency_max = MT_freq_max;
spectrogram_parameters.taper_params = MT_taper;
spectrogram_parameters.window_params = MT_window;
spectrogram_parameters.min_NFFT = MT_min_NFFT;
spectrogram_parameters.detrend = MT_detrend;
spectrogram_parameters.weighting = MT_weighting;
spectrogram_parameters.ploton = false;
spectrogram_parameters.verbose = verbose;
spectrogram_parameters.xyflip = true;

% select which version of multitaper_spectrogram to run
if exist('multitaper_spectrogram_mex', 'file') == 2
    multitaper_version = @multitaper_spectrogram_mex;
elseif exist('multitaper_spectrogram', 'file') == 2
    multitaper_version = @multitaper_spectrogram;
else
    error('Cannot locate multitaper_spectrogram functions.')
end

[spect,stimes,sfreqs]=multitaper_version(single(EEG'), Fs,...
    [0 min([Fs/2 spectrogram_parameters.frequency_max])], ...
    spectrogram_parameters.taper_params,spectrogram_parameters.window_params, ...
    spectrogram_parameters.min_NFFT, spectrogram_parameters.detrend, ...
    spectrogram_parameters.weighting,...
    spectrogram_parameters.ploton, spectrogram_parameters.verbose,...
    spectrogram_parameters.xyflip);

end

function [ detection_inds, normalization_inds, stages_in_stimes ] = select_time_indices(stages_input, EEG, Fs, stimes, normalization_stages, detection_stages, artifact_detect, artifact_filters)
%stages_input should be in the format [time at change, new stage] as two
%long column vectors, i.e., each row is [time at change, new stage].
stages_in_stimes = interp1(stages_input(:,1), stages_input(:,2), stimes, 'previous');

%detects artifacts, changes those times to wake periods in stages_stimes
if artifact_detect == true
    hpFilt_high = artifact_filters.hpFilt_high;
    hpFilt_broad = artifact_filters.hpFilt_broad;
    artifacts = detect_artifacts(EEG, Fs, 'hf_crit',3.5, 'hf_pass',35, 'bb_crit',3.5, 'bb_pass',2,...
    'smooth_duration',2, 'hpFilt_high',hpFilt_high, 'hpFilt_broad',hpFilt_broad);
    artifacts_times = 0:1/Fs:(length(EEG)-1)/Fs;
    artifacts_in_stimes = interp1(artifacts_times, double(artifacts), stimes, 'previous');
    stages_in_stimes(artifacts_in_stimes == 1) = 6; % mark artifacts as 6
elseif artifact_detect == false
else
    assert(length(artifact_detect) == length(EEG), 'Incorrect artifact vector length.')
    artifacts = artifact_detect;
    artifacts_times = 0:1/Fs:(length(EEG)-1)/Fs;
    artifacts_in_stimes = interp1(artifacts_times, double(artifacts), stimes, 'previous');
    stages_in_stimes(artifacts_in_stimes == 1) = 6; % mark artifacts as 6
end

%extracting the valid normalization times
normalization_inds = ismember(stages_in_stimes, normalization_stages);

%extracting the valid detection times
% stages: 1xN vector of stage values (0:Undefined, 5:Wake, 4:REM, 3:N1, 2:N2, 1:N3)
detection_inds = ismember(stages_in_stimes, detection_stages);
end

function [ fh ] = TF_peak_plot(spect, stimes, sfreqs, stages_in_stimes, spindle_table)

fh = figure;
ax = figdesign(5,1, 'type','usletter', 'margins', [.05 .15 .05 .05 .03], 'merge',{2:5});
set(fh, 'units','normalized','position',[0 0 1 1]);
linkaxes(ax,'x');
h_timetextstart = uicontrol('style', 'text', 'String', 'Window: ---', 'units', 'normalized', ...
    'Position', [0.0051    0.9677    0.17    0.0305], 'BackgroundColor', [1 1 1], ...
    'HorizontalAlignment', 'left');
addlistener(ax(2), 'XLim', 'PostSet', @(src,evnt)update_time_range(ax(2), h_timetextstart));

axes(ax(1));
hypnoplot(stimes, stages_in_stimes);
title('Hypnogram');
set(gca, 'FontSize', 16)

axes(ax(2));
imagesc(stimes, sfreqs, nanpow2db(spect'));
axis xy;
colormap jet;
climscale;
title('Spectrogram');
xlabel('Time (sec)');
ylabel('Frequency (Hz)');
set(gca, 'xtick', []);
set(gca, 'FontSize', 16)

hold on;
for ii = 1:size(spindle_table,1)
    pos = [ spindle_table.Start_Time(ii), spindle_table.Freq_Low(ii),...
        spindle_table.Duration(ii), spindle_table.Freq_High(ii)-spindle_table.Freq_Low(ii) ];
    r(ii) = rectangle('Position', pos,'LineStyle',':','EdgeColor','k','LineWidth',2); %#ok<AGROW>
end
set(fh,'KeyPressFcn',@(src,event)handle_keys(event, r));
update_time_range(ax(2), h_timetextstart);
scrollzoompan;
msgbox('Press ''v'' to toggle visibility of TF-Peak bounding boxes');
end

function update_time_range(ax, h_timetext)

time_range = xlim(ax);
df = datenum([0 0 0 0 0 1]);
h_timetext.String = ['Window: ', datestr(df*time_range(1), 'HH:MM:SS'), ' - ', ...
    datestr(df*time_range(2), 'HH:MM:SS')];

end

function [ spindle_table ] = create_output_tbl(stimes, stages_in_stimes, TFpeak_times, clustering_idx, clustering_prom_order, tpeak_center_times, tpeak_central_frequencies, tpeak_bandwidth_bounds, tpeak_proms)

start_time = TFpeak_times(:,1);
end_time = TFpeak_times(:,2);
candidate_spindle_index = clustering_idx == clustering_prom_order(1);
center_time = tpeak_center_times(candidate_spindle_index);
central_freq = tpeak_central_frequencies(candidate_spindle_index);
duration = end_time - start_time;
freq_low = tpeak_bandwidth_bounds(candidate_spindle_index,1);
freq_high = tpeak_bandwidth_bounds(candidate_spindle_index,2);
prom_value = tpeak_proms(candidate_spindle_index);
peak_volume = prom_value .* duration .* (freq_high - freq_low);
spindle_stage = interp1(stimes, stages_in_stimes, center_time, 'nearest');

% instantiate the table
var_names = {'Start_Time','End_Time','Max_Prominence_Time','Prominence_Value','Duration','Freq_Central','Freq_Low','Freq_High','Peak_Volume','Stage'};
spindle_table = table(start_time, end_time, center_time, prom_value, duration, central_freq, freq_low, freq_high, peak_volume, spindle_stage, 'VariableNames', var_names);

end

function ydB = nanpow2db(y)
ydB = (10.*log10(y)+300)-300;
ydB(y(:)<=0) = nan;
end

function [] = handle_keys(event, rh)
%Check for hotkeys pressed
switch lower(event.Character)
    case 'v'
        if strcmp(rh(1).Visible, 'on') || all(rh(1).Visible==1)
            set(rh, 'Visible', false);
        else
            set(rh, 'Visible', true);
        end
end
end
