%%%% Script to run all Lunesta subjects through SO power and phase analyses
% Tom P
ccc;

%% Set data and output directories
peaksdata_dir = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2/'; 
save_dir = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/';

%% SO power/phase input parameters
SO_stage_include = [1,2,3,4,5];
freq_range = [0,40];
freq_binsizestep = [0.05, 0.05]; %[0.5, 0.1];
SOpow_range = [0,1];
SOpow_binsizestep = [0.005, 0.005]; %[0.05, 0.01];
min_time_in_bin_SOpow = 0;
SOphase_range = [-pi, pi];
SOphase_binsizestep = [(2*pi)/400, (2*pi)/400]; %[1, 0.05];
SOphase_filter = [];
pow_freqSO_norm = [false, false];
phase_freqSO_norm = [false, false];
lightsonoff_mins = 5;
rate_flag = false;
plot_flag = false;

%% Calculate number of bins
nbins_freq = ( (freq_range(2) - freq_binsizestep(1)) / freq_binsizestep(2) ) + 2;
nbins_SOpow = ( (SOpow_range(2) - SOpow_binsizestep(1)) / SOpow_binsizestep(2) ) + 2;
nbins_SOphase = round( (SOphase_range(2) - SOphase_range(1)) / SOphase_binsizestep(2) );

%% Set subjects, electrodes, nights
cntrl_subjs = [3]; %[1 3 5 6 7 8 9 10 11 12 13 15 17 18 19 20 21]; 
sz_subjs  = [14,17,19,24]; %[1 4 5 7 8 9 10 11 13 14 15 17 18 19 20 21 22 23 24 25 26 30 31];

subjects = [cntrl_subjs'; sz_subjs'];
issz = [false(length(cntrl_subjs),1); true(length(sz_subjs),1)];
nights = [1,2];
electrodes = {'C3', 'C4', 'F3', 'F4', 'O1', 'O2', 'Pz'};

% Set codes for which subjects/nights/elects need manual lights on/off times
manual_timeselect_codes = {'S14n1C3', 'S14n1C4', 'S14n1F3', 'S14n1F4', 'S14n1O1', 'S14n1O2',...
                           'S14n1Pz', 'S17n1C4', 'S17n2C3', 'S19n1F3', 'S24n1C3', 'S24n1C4',...
                           'S24n1F3', 'S24n1F4', 'S24n1O1', 'S24n1O2', 'S24n1Pz', 'S24n2C3',...
                           'S24n2C4', 'S24n2F3', 'S24n2F4', 'S24n2O1', 'S24n2O2', 'S24n2Pz',...
                           '3n1O1'};
                       
% Set manual lights on/off times
manual_timeselects = {[7380,41130], [7380,41130], [7380,41130], [7380,41130], [7380,41130], [7380,41130], [7380,41130], [15480,37650],...
                      [5940,29070], [13800,39210], [5520,32340], [5520,32340], [5520,32340], [5520,32340], [5520,32340], [5520,32340],...
                      [5520,32340], [5250, 26190], [5250, 26190], [5250, 26190], [5250, 26190], [5250, 26190], [5250, 26190],...
                      [5250, 26190], [1080,26760]};

num_electrodes = length(electrodes);
num_subjects = length(subjects);
num_nights = length(nights);
num_SO_mats = length(SO_stage_include);

%% Set results storage
SOpow_data = cell(1,num_electrodes);
SOphase_data = cell(1,num_electrodes);
SOpow_time_data = cell(1,num_electrodes);
SOphase_time_data = cell(1,num_electrodes);
SOpow_prop_data = cell(1,num_electrodes);
SOphase_prop_data = cell(1,num_electrodes);

%% Precompute artifact detection filters
Fs = 100; % Lunesta 100Hz
hpFilt_high = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',25,'PassbandRipple',0.2, 'SampleRate',Fs);
hpFilt_broad = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',0.1,'PassbandRipple',0.2, 'SampleRate',Fs);
detrend_filt = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',0.001,'PassbandRipple',0.2, 'SampleRate',Fs);

%% 
loading_errors = [];

for ee = 1:num_electrodes
    
    % Set up single electrode results storage
    single_electrode_data_pow = nan(nbins_SOpow, nbins_freq, num_subjects, num_nights, num_SO_mats);
    single_electrode_data_phase = nan(nbins_SOphase, nbins_freq, num_subjects, num_nights, num_SO_mats);
    single_electrode_timedata_pow = nan(nbins_SOpow, num_subjects, num_nights, num_SO_mats);
    single_electrode_timedata_phase = nan(nbins_SOphase, num_subjects, num_nights, num_SO_mats);
    single_electrode_propdata_pow = nan(nbins_SOpow, num_subjects, num_nights, num_SO_mats);
    single_electrode_propdata_phase = nan(nbins_SOphase, num_subjects, num_nights, num_SO_mats);


    for s = 1:num_subjects
        % Set string to determine SZ or control data gets loaded
        if issz(s) == true
            lun_str = 'S';
        else
            lun_str = '';
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

            
            stages = interp1(stages.time, stages.stage, t, 'previous', 'extrap'); % Get stages in t timepoints
            stages(1) = stages(2); % fix first stage because it's NaN 
            
            % Run artifact detection
            artifacts = detect_artifacts(EEG, Fs, [], [], [], [], [], [], [], [], [], hpFilt_high, hpFilt_broad, detrend_filt);
            
            % Compute lightson/lightsoff times
            timeselect_code_curr = [lun_str, num2str(curr_subj), 'n', num2str(curr_night), electrodes{ee}];
            is_manual_timeselect = ismember(manual_timeselect_codes, timeselect_code_curr);
            
            if sum(is_manual_timeselect) > 0 
                time_range(1) = manual_timeselects{is_manual_timeselect}(1);
                time_range(2) = manual_timeselects{is_manual_timeselect}(2);
            else
                time_range(1) = max( min(t(stages~=5))-lightsonoff_mins*60, 0); % x min before first non-wake stage 
                time_range(2) = min( max(t(stages~=5))+lightsonoff_mins*60, max(t)); % x min after last non-wake stage
            end

            % Load TFpeak data from watershed
            if isfile([peaksdata_dir, 'Lun', lun_str, num2str(curr_subj), '_', curr_electrode, '_', num2str(curr_night), '/peakstats_tbl.mat'])
                saveout_table = load([peaksdata_dir, 'Lun', lun_str, num2str(curr_subj), '_', curr_electrode, '_', num2str(curr_night), '/peakstats_tbl.mat'], 'saveout_table');
                saveout_table = saveout_table.saveout_table;
            else
                disp([peaksdata_dir, 'Lun', lun_str, num2str(curr_subj), '_', curr_electrode, '_', num2str(curr_night), '/peakstats_tbl.mat', ' not found - skipping subject'])
                continue
            end
            
            peak_times = saveout_table.xy_wcentrd(:,1);
            peak_freqs = saveout_table.xy_wcentrd(:,2);
            
            saveout_table = [];
            
            tic;
            
            for ii = 1:num_SO_mats
                
                % Set stages to exclude
                stage_exclude = ~ismember(stages, SO_stage_include(ii));

                % Run SO power 
                [SOpow_mat, freq_cbins, SOpow_cbins, TIB_pow, PIB_pow] = SOpower_histogram(EEG, Fs, peak_freqs, peak_times, 'SO_binsizestep', SOpow_binsizestep, 'freq_binsizestep',...
                                                                                            freq_binsizestep, 'stage_exclude', stage_exclude, 'artifacts', ...
                                                                                            artifacts, 'min_time_in_bin', min_time_in_bin_SOpow, 'time_range', ...
                                                                                            time_range, 'rate_flag', rate_flag, 'plot_flag', plot_flag);                
                
                % Run SO phase 
                [SOphase_mat, ~, SOphase_cbins, TIB_phase, PIB_phase] = SOphase_histogram(-EEG, Fs, peak_freqs, peak_times, 'SO_binsizestep', SOphase_binsizestep, 'freq_binsizestep', ...
                                                                                           freq_binsizestep, 'stage_exclude', stage_exclude, ...
                                                                                           'artifacts', artifacts, 'phase_freqSO_norm', phase_freqSO_norm, ...
                                                                                           'time_range', time_range, 'rate_flag', rate_flag, 'plot_flag', plot_flag);
                % Store results
                single_electrode_data_pow(:,:,s,n,ii) = SOpow_mat;
                single_electrode_data_phase(:,:,s,n,ii) = SOphase_mat;
                single_electrode_timedata_pow(:,s,n,ii) = TIB_pow;
                single_electrode_timedata_phase(:,s,n,ii) = TIB_phase;
                single_electrode_propdata_pow(:,s,n,ii) = PIB_pow;
                single_electrode_propdata_phase(:,s,n,ii) = PIB_phase;
                
            end % end SO mats
            
            toc;
            
        end % end nights
        
    end % end subject
    
    
    % Store data for saving
    SOpow_data{ee} = single_electrode_data_pow;
    SOphase_data{ee} = single_electrode_data_phase;
    SOpow_time_data{ee} = single_electrode_timedata_pow;
    SOphase_time_data{ee} = single_electrode_timedata_phase;
    SOpow_prop_data{ee} = single_electrode_propdata_pow;
    SOphase_prop_data{ee} = single_electrode_propdata_phase;
    
    % Save
    
    [~, SOpow_cbins] = create_bins([0,1], SOpow_binsizestep(1), SOpow_binsizestep(2));
    [~, SOphase_cbins] = create_bins([-pi,pi], SOphase_binsizestep(1), SOphase_binsizestep(2), 'extend');
    [~, freq_cbins] = create_bins([0,40], freq_binsizestep(1), freq_binsizestep(2));
    
    save([save_dir, 'SOpow_data_smallbin_timecut3_14_17_19_24.mat'], 'SOpow_data', 'SOpow_time_data', 'SOpow_prop_data', 'freq_cbins', 'SOpow_cbins', 'subjects', 'issz', 'electrodes', '-v7.3');
    save([save_dir, 'SOphase_data_smallbin_timecut3_14_17_19_24.mat'], 'SOphase_data', 'SOphase_time_data', 'SOphase_prop_data', 'freq_cbins', 'SOphase_cbins', 'subjects', 'issz', 'electrodes', '-v7.3');
    
end % end electrode











