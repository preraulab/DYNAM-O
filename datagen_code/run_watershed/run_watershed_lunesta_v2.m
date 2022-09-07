%% (Re)Run Watershed algorithm on Lunesta data %%


%%
ccc;

total_start = tic;

%% set up a result dump folder
savefolder_name = '/data/preraugp/users/tjp42/watershed_paper_recode/run_watershed/watershed_results_v2/';
if ~isfolder(savefolder_name)
    mkdir(savefolder_name)
end

%% Set subjects to run on
SZ = false;

if SZ == true
    group = 'LunS';
    subj_IDs = [1 4 5 7 8 9 10 11 13 14 15 17 18 19 20 21 22 23 24 25 26 30 31];
elseif SZ == false
    group = 'Lun';
    subj_IDs = [1 3 5 6 7 8 9 10 11 12 13 15 17 18 19 20 21];
end

% nonSZ: 1 3 5 6 7 8 9 10 11 12 13 15 17 18 19 20 21 
% SZ: 1 4 5 7 8 9 10 11 13 14 15 17 18 19 20 21 22 23 24 25 26 30 31


%% Init variables for looping
channel = {'C3', 'C4', 'F3', 'F4', 'O1', 'O2', 'Pz', 'X1'};
num_subject = length(subj_IDs);
N_chan = length(channel);
num_nights = 2;
size_res = num_subject*N_chan*num_nights;

%% Init mt spect params
freq_range = [0,40]; % frequency range to compute spectrum over
taper_params = [2,3]; % [time halfbandwidth product, number of tapers]
time_window_params = [1,0.05]; % [time window, time step] in seconds
nfft = 2^10; % zero pad data to this minimum value for fft
detrend = 'off'; % do not detrend 
ploton = false; % do not automatically plot

%% Init Watershed variables
lightsonoff_mins = 5;
verbose = 2;
f_save = 1; % save less peak stats out


%% Run watershed on subjects
count = 0;
for s = 1:length(subj_IDs)
    for n = 1:num_nights
        for ee = 1:N_chan
            errors = [];
            full_filepath = [savefolder_name, group, num2str(subj_IDs(s)), '_', channel{ee}, '_', num2str(n), '/'];
            if ~isfolder(full_filepath)
                tic;
                count = count + 1;

                ofile_pref = full_filepath;
                mkdir(ofile_pref)
                                
                try
                    %% Load subject data
                    [EEG, Fs, t, labels, stages] = load_Lunesta_data(subj_IDs(s), n, 'SZ', SZ , 'channels', channel{ee});
                    assert(size(EEG,1) == 1, 'Multiple electrodes returned');
                    stages = interp1(stages.time, stages.stage, t, 'previous'); % interpolate stages to make sure they're same len as t            

                catch e 
                    disp(['Subj ', num2str(subj_IDs(s)), ' error loading'])
                    errors = e;
                    save([full_filepath, '/errors.mat'], 'errors');
                    continue
                end

                disp(['Subj ', num2str(subj_IDs(s)), ' Night ', num2str(n), ' Channel ', num2str(channel{ee}), ' loaded.'])
                
                %% Compute Spectrogram
                [spect,stimes,sfreqs] = multitaper_spectrogram_mex(EEG, Fs, freq_range, taper_params, time_window_params, nfft, detrend, [], ploton);
                
                %% Compute baseline spectrum used to flatten data spectrum
                time_range(1) = min(t(stages~=5))-lightsonoff_mins*60; % x min before first non-wake stage 
                time_range(2) = max(t(stages~=5))+lightsonoff_mins*60; % x min after last non-wake stage
                time_range_stimes = ( stimes >= time_range(1) ) & ( stimes <= time_range(2) );
                
                artifacts = detect_artifacts(EEG, Fs);
                artifacts_stimes = logical(interp1(t, double(artifacts), stimes, 'nearest'));
                
                bad_inds_stimes = ~time_range_stimes | artifacts_stimes;

                spect_bl = spect; % copy spectogram
                spect_bl(:,bad_inds_stimes) = NaN; % turn artifact times and lightson times into NaNs 

                spect_bl(spect==0) = NaN; % Turn 0s to NaNs for percentile computation

                baseline_ptile = 2; % using 2nd percentile of spectrogram as baseline
                baseline = prctile(spect_bl, baseline_ptile, 2); % Get baseline

                %% Run watershed
                
                [matr_names, matr_fields, peaks_matr, PixelIdxList, PixelList, PixelValues, ...
                    rgn, bndry, chunks_minmax, chunks_xyminmax, chunks_time, bad_chunks, chunk_error] ... 
                    = extract_TFpeaks(spect, stimes, sfreqs, baseline, [], [], [], [], [], [], [], [], [], [], [], verbose, [], [], f_save, ofile_pref);
                toc;

            end
            
        end % end channels
        
    end % end nights
    
end % end subjectslts

toc(total_start);


