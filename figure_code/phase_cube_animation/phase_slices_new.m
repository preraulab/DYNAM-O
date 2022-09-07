% Data: night 2 HC only
% Goal: Get average SOphase hists for each SO power bin
% Method:
%   Must be done in a outer loop over subjects because limiting factor is
%   time it takes to load in TFpeak data for each subj and we cannot load
%   in all TFpeak data for all subjects at once. Should be able to
%   parallelize on outer subject loop.
%     - For each subj calculate SOpower (following method in
%     SOpower_histogram function), then find times and freqs of peaks in
%     specific SOpow (bin). Run those peaks through SOphase_histogram function
%     to get SOphase hist
%     - Once  done for all subjs, average each SOpow bin's SOphase hist over all subjs
%       to get single SOphase hist for each SOpow bin


ccc;
addpath(genpath('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/watershed_TFpeaks_toolbox'));

%% Set TFpeak directorie
peaksdata_dir = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2/';
save_dir = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOphase_slice_data/';

%% SO power/phase input parameters
SO_stage_include = [1,2,3,4];
freq_range = [0,40];
freq_binsizestep = [0.5, 0.1];
SOpow_range = [0,1];
SOpow_binsizestep = [0.1, 0.01];
min_time_in_bin_SOpow = 0;
SOphase_range = [-pi, pi];
SOphase_binsizestep = [1, 0.05];
SOphase_filter = [];
pow_freqSO_norm = [false, false];
phase_freqSO_norm = [false, false];
SO_freqrange = [0.3,1.5];
lightsonoff_mins = 5;
rate_flag = false;
plot_flag = false;

%% Calculate number of bins
nbins_freq = ( freq_range(2)  / freq_binsizestep(2) ) + 1;
nbins_SOphase = floor(( (SOphase_range(2) - SOphase_range(1)) / SOphase_binsizestep(2) ) + 1 );

%% Set subjects, electrodes, nights
cntrl_subjs = [1 3 5 6 7 8 9 11 12 13 15 17 18 19 20 21]';

subjects = cntrl_subjs;
issz = false(length(cntrl_subjs),1);
nights = 2;
electrodes = {'F3','C3','Pz','O1'};

num_electrodes = length(electrodes);
num_subjects = length(subjects);
num_nights = length(nights);

%% Set results storage
SOphase_slice_data = cell(1,num_electrodes);
SOphase_slice_time_data = cell(1,num_electrodes);

%% Precompute artifact detection filters
Fs = 100; % Lunesta 100Hz
hpFilt_high = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',25,'PassbandRipple',0.2, 'SampleRate',Fs);
hpFilt_broad = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',0.1,'PassbandRipple',0.2, 'SampleRate',Fs);
detrend_filt = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',0.001,'PassbandRipple',0.2, 'SampleRate',Fs);

%% Set SO pow bins
[SO_bin_edges, SO_cbins] = create_bins([0 1], SOpow_binsizestep(1), SOpow_binsizestep(2), 'partial');
num_SObins = length(SO_cbins);


%%
for ee = 1:num_electrodes
    % Set up single electrode results storage
    single_electrode_data_phase = nan(nbins_SOphase, nbins_freq, num_subjects, num_SObins);
    single_electrode_timedata_phase = nan(nbins_SOphase, num_subjects, num_SObins);

    for s = 1:num_subjects
        tic;
        curr_subj = subjects(s);
        curr_electrode = electrodes{ee};

        %% Load subject data
        try
            [EEG, Fs, t, ~, stages] = load_Lunesta_data(curr_subj, 2, 'SZ', false , 'channels', curr_electrode);
            assert(size(EEG,1) == 1, 'Multiple electrodes returned');
        catch
                disp(['Subj ', num2str(curr_subj), ', Night 2, Channel ', num2str(curr_electrode), ' error loading'])
                continue
        end
        
        disp(['Subj ', num2str(curr_subj), ', Night 2, Channel ', num2str(curr_electrode), ' loaded.'])

        stages = interp1(stages.time, stages.stage, t, 'previous', 'extrap'); % Get stages in t timepoints
        stages(1) = stages(2); % fix first stage because it's NaN

        %% Run artifact detection
        artifacts = detect_artifacts(EEG, Fs, [], [], [], [], [], [], [], [], [], hpFilt_high, hpFilt_broad, detrend_filt);

        %% Calculate lights on/off
        time_range_start = max( min(t(stages~=5))-lightsonoff_mins*60, 0); % x min before first non-wake stage
        time_range_stop = min( max(t(stages~=5))+lightsonoff_mins*60, max(t)); % x min after last non-wake stage

        %% Load TFpeak data from watershed
        saveout_table = load([peaksdata_dir, 'Lun', num2str(curr_subj), '_', curr_electrode, '_2', '/peakstats_tbl.mat'], 'saveout_table');
        saveout_table = saveout_table.saveout_table;

        peak_times = saveout_table.xy_wcentrd(:,1); % get peak times
        peak_freqs = saveout_table.xy_wcentrd(:,2); % get peak freqs

        %% Set stages to exclude
        stage_exclude = ~ismember(stages, SO_stage_include);

        %% replace artifact timepoints with NaNs
        nanEEG = EEG;
        nanEEG(artifacts) = nan;

        %% Compute SO power
        [SOpower, SOpower_times] = compute_mtspect_power(nanEEG, Fs, 'freq_range', SO_freqrange);

        %% Normalize SO power
        ptiles = prctile(SOpower(SOpower_times>=time_range_start & SOpower_times<=time_range_stop), [1, 99]);
        SOpower_norm = SOpower - ptiles(1);
        SOpower_norm = SOpower_norm/(ptiles(2) - ptiles(1));

        %% Sort TFpeak time and frequency data
        [peak_times, sortinds] = sort(peak_times);
        peak_freqs = peak_freqs(sortinds);

        %% Get valid peak inds
        %Get indices of peaks that occur during artifact
        artifact_inds_peaks = logical(interp1(t, double(artifacts), peak_times, 'nearest'));

        % Get indices of peaks that are in selected sleep stages
        stage_inds_peaks = logical(interp1(t, double(~stage_exclude), peak_times, 'nearest'));

        % Get indices of peaks that occur inside selected time range
        timerange_inds_peaks = (peak_times >= time_range_start) & (peak_times <= time_range_stop);

        % Combine all indices to select peaks that occur during valid stages/times
        peak_selection_inds = stage_inds_peaks & ~artifact_inds_peaks & timerange_inds_peaks;

        %% Get valid SOpower values
        % Exclude unwanted stages and times
        SOpower_stages_valid = logical(interp1(t, double(~stage_exclude), SOpower_times, 'nearest'));
        SOpower_times_valid = (SOpower_times>=time_range_start & SOpower_times<=time_range_stop);
        SOpower_valid = SOpower_stages_valid & SOpower_times_valid;

        SOpower_norm(~SOpower_valid) = nan;

        %% Get SOpower at each peak time
        peak_SOpower_norm = interp1(SOpower_times, SOpower_norm, peak_times);
        
        %% Loop through SO pow bins
        for n = 1:num_SObins

                % Get indices of TFpeaks that occur in this SOpow bin
                SO_inds = (peak_SOpower_norm >= SO_bin_edges(1,n)) & (peak_SOpower_norm < SO_bin_edges(2,n)) & peak_selection_inds;

                % Run SO phase 
                if isempty(peak_freqs(SO_inds))
                    disp(['No peaks found for SO bin ', num2str(n), ' for electrode ', electrodes{ee}])
                    continue
                end
                [SOphase_mat, freq_cbins_store, SOphase_cbins_store, TIB_phase, ~] = SOphase_histogram(-EEG, Fs, peak_freqs(SO_inds), peak_times(SO_inds), ...
                                                                            'SO_binsizestep', SOphase_binsizestep, 'freq_binsizestep', ...
                                                                            freq_binsizestep, 'stage_exclude', stage_exclude, ...
                                                                            'artifacts', artifacts, 'phase_freqSO_norm', phase_freqSO_norm, ...
                                                                            'time_range', [time_range_start, time_range_stop], 'rate_flag', ...
                                                                            rate_flag, 'plot_flag', plot_flag);
                single_electrode_data_phase(:,:,s,n) = SOphase_mat;
                single_electrode_timedata_phase(:,s,n) = TIB_phase;
        end

        toc
    end

    sum_phase_slices = squeeze(sum(single_electrode_data_phase, 3, 'omitnan'));
    sum_phase_slices = permute(sum_phase_slices, [1,3,2]);
    sum_phase_slices_timedata_slices = squeeze(sum(single_electrode_timedata_phase, 2, 'omitnan'));
    average_phase_slices = sum_phase_slices ./ sum_phase_slices_timedata_slices;
    average_phase_slices = permute(average_phase_slices , [1,3,2]);

    average_phase_slices = average_phase_slices ./ sum(average_phase_slices,1); % normalize
    

    SOphase_slice_data{ee} = average_phase_slices;
    save(fullfile(save_dir, 'SOphase_slice_data_10percPowBins_v1.mat'), 'SOphase_slice_data', 'electrodes', '-v7.3');

end










