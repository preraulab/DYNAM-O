function [SOpowhist_data, SOpow_time_data, SOpow_prop_data, SOpow_cbins_all, freq_cbins, SOpow_data, staging] = ...
    alternative_normalizations_pow(subjects, electrodes, nights, issz, SO_range, freq_range,...
    SO_binsizestep, freq_binsizestep, norm_method, stages_include, min_time_in_bin_SOpow, ...
    art_filts, plot_flag, rate_flag)
%
%
%
%
%

if nargin < 13 || isempty(art_filts)
    art_filts = false;
end

if nargin < 15 || isempty(plot_flag)
    plot_flag = false;
end

if nargin < 16 || isempty(rate_flag)
    rate_flag = true;
end

%% Set data directory
peaksdata_dir = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2/';

%% Unpack artifact detection filters
if ~islogical(art_filts)
    hpFilt_high = art_filts.hpFilt_high;
    hpFilt_broad = art_filts.hpFilt_broad;
    detrend_filt = art_filts.detrend_filt;
end

%% Calculate number of bins
nbins_freq = ( (freq_range(2) - freq_range(1)) / freq_binsizestep(2) ) + 1;
nbins_SOpow = ( (SO_range(2)-SO_range(1)) / SO_binsizestep(2) ) + 1;

%% Set results storage
num_electrodes = length(electrodes);
num_subjects = length(subjects);
num_nights = length(nights);

SOpowhist_data = cell(1,num_electrodes);
SOpow_cbins_all = cell(1, num_electrodes);
SOpow_time_data = cell(1,num_electrodes);
SOpow_prop_data = cell(1,num_electrodes);
SOpow_data = cell(1,num_electrodes);
staging = cell(1, num_electrodes);


%% Get SO power for each night for each electrode
for ee = 1:num_electrodes

    % Set up single electrode results storage
    single_electrode_data_pow = nan(nbins_SOpow, nbins_freq, num_subjects, num_nights);
    single_electrode_SObin_data = nan(nbins_SOpow, num_subjects, num_nights);
    single_electrode_timedata_pow = nan(nbins_SOpow, 5, num_subjects, num_nights);
    single_electrode_propdata_pow = nan(nbins_SOpow, 5,  num_subjects, num_nights);
    single_electrode_SOpow_timeseries_data = cell(num_subjects, num_nights);
    single_electrode_staging = cell(num_subjects, num_nights);

    parfor s = 1:num_subjects %%%parfor
        % Set string to determine SZ or control data gets loaded
        if issz(s) == true
            lun_str = 'LunS';
        else
            lun_str = 'Lun';
        end

        time_range = [];

        for n = 1:num_nights

            curr_subj = subjects(s);
            curr_night = nights(n);
            curr_issz = issz(s);
            curr_electrode = electrodes{ee};

            try
                %% Load subject data
                [EEG, Fs, t, ~, stages] = load_Lunesta_data(curr_subj, curr_night, 'SZ', curr_issz , 'channels', curr_electrode);
                assert(size(EEG,1) == 1, 'Multiple electrodes returned');

            catch e
                disp(['Subj ', num2str(curr_subj), ' Night ', num2str(curr_night), ' Channel ', num2str(curr_electrode), ' error loading'])
                continue
            end

            disp(['Subj ', num2str(curr_subj), ' Night ', num2str(curr_night), ' Channel ', num2str(curr_electrode), ' loaded.'])


            stages_full = interp1(stages.time, stages.stage, t, 'previous', 'extrap'); % Get stages in t timepoints
            stages_full(1) = stages_full(2); % fix first stage because it's NaN

            % Run artifact detection
            if islogical(art_filts)
                if art_filts
                    artifacts = detect_artifacts(EEG, Fs);
                else
                    artifacts = false(length(EEG),1);
                end
            else
                artifacts = detect_artifacts(EEG, Fs, [], [], [], [], [], [], [], [], [], hpFilt_high, hpFilt_broad, detrend_filt);
            end
            
            % Get stages to exclude
            stage_exclude = ~ismember(stages_full, stages_include);

            % Compute lightson/lightsoff times
            time_range(1) = max( min(t(stages_full~=5))-5*60, 0); % x min before first non-wake stage
            time_range(2) = min( max(t(stages_full~=5))+5*60, max(t)); % x min after last non-wake stage

            % Load TFpeak data from watershed
            if isfile([peaksdata_dir, lun_str, num2str(curr_subj), '_', curr_electrode, '_', num2str(curr_night), '/peakstats_tbl.mat'])
                saveout_table = load([peaksdata_dir, lun_str, num2str(curr_subj), '_', curr_electrode, '_', num2str(curr_night), '/peakstats_tbl.mat'], 'saveout_table');
                saveout_table = saveout_table.saveout_table;
            else
                continue
            end

            peak_times = saveout_table.xy_wcentrd(:,1);
            peak_freqs = saveout_table.xy_wcentrd(:,2);

            %clear saveout_table;

            tic;

            % Run SO power
            [SOpow_mat, ~, SOpow_cbins, TIB_pow, PIB_pow, ~, ~, SOpow_norm, ~, SOpow_times] = ...
                SOpower_histogram_allstageTIB(EEG, Fs, peak_freqs, peak_times, stages_full, 'freq_range', freq_range,...
                'SO_binsizestep', SO_binsizestep, 'freq_binsizestep', freq_binsizestep, ...
                'artifacts', artifacts, 'norm_method', norm_method, 'min_time_in_bin', min_time_in_bin_SOpow,...
                'time_range', time_range, 'SO_range', SO_range, 'rate_flag', rate_flag, 'plot_flag',...
                plot_flag, 'stage_exclude', stage_exclude);

            % Store results
            single_electrode_data_pow(:,:,s,n) = SOpow_mat;
            single_electrode_SObin_data(:,s,n) = SOpow_cbins;
            single_electrode_timedata_pow(:,:,s,n) = TIB_pow;
            single_electrode_propdata_pow(:,:,s,n) = PIB_pow;
            single_electrode_SOpow_timeseries_data{s,n} = [SOpow_norm, SOpow_times'];
            stages_full(artifacts) = 6;
            single_electrode_staging{s,n}= stages_full;

            toc;

        end % end nights

    end % end subject

    % Store data for saving
    SOpowhist_data{ee} = single_electrode_data_pow;
    SOpow_cbins_all{ee} = single_electrode_SObin_data;
    SOpow_time_data{ee} = single_electrode_timedata_pow;
    SOpow_prop_data{ee} = single_electrode_propdata_pow;
    SOpow_data{ee} = single_electrode_SOpow_timeseries_data;
    staging{ee} = single_electrode_staging;

end % end electrode

[~, freq_cbins] = create_bins(freq_range, freq_binsizestep(1), freq_binsizestep(2), 'partial');

end

