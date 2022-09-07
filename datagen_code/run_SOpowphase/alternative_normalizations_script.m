%%% Script to run 

%% Set path to get necessary functions
addpath(genpath('/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/watershed_TFpeaks_toolbox'))

%% Set data and output directories
peaksdata_dir = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/watershed_results_v2/'; 
save_dir = '/data/preraugp/projects/transient_oscillations/transient_oscillations_paper/results/SOpowphase_results/SOpower_alternative_normalization_figure_data/';

%% SO power/phase input parameters
SO_stage_include = [1,2,3,4,5];
freq_range = [0,40];
freq_binsizestep = [1, 0.2];
SOpow_range = [0 40]; % [0 1] [0 1] [-5, 25], [0, 40]
SOpow_binsizestep = [8, 0.4]; % [0.2, 0.01] [0.2, 0.01] [6, 0.3], [8, 0.4]
min_time_in_bin_SOpow = 5;
norm_method = 'absolute'; % 'percentile', 'proportion', 'shift', 'absolute'
rate_flag = true;
plot_flag = false;

%% Set subjects, electrodes, nights
cntrl_subjs = [8 9 10 11 12 13 15 17 18 19 20 21]; %1 3 5 6  7

subjects = cntrl_subjs';
issz = false(length(cntrl_subjs),1);
nights = [2];
electrodes = {'C3', 'C4', 'F3', 'F4', 'O1', 'O2', 'Pz', 'X1'};

%% Initialize artifact detection filters
Fs = 100; % Lunesta 100Hz
art_filts.hpFilt_high = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',25,'PassbandRipple',0.2, 'SampleRate',Fs);
art_filts.hpFilt_broad = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',0.1,'PassbandRipple',0.2, 'SampleRate',Fs);
art_filts.detrend_filt = designfilt('highpassiir','FilterOrder',4, 'PassbandFrequency',0.001,'PassbandRipple',0.2, 'SampleRate',Fs);

%% Get SOpows
[SOpowhist_data, SOpow_time_data, SOpow_prop_data, SOpow_cbins, freq_cbins, SOpow_data] = alternative_normalizations_pow(subjects,...
                electrodes, nights, issz, SOpow_range, freq_range, SOpow_binsizestep, freq_binsizestep, norm_method,...
                SO_stage_include, min_time_in_bin_SOpow, art_filts, plot_flag, rate_flag);

%% Save out
%SOpow_data = cellfun(@(x) nanmean(x,3), SOpow_data, 'UniformOutput', false);
save([save_dir, 'SOpow_data_', norm_method, '_fullrecord_n1.mat'], 'SOpowhist_data', 'SOpow_data', ...
    'SOpow_time_data', 'SOpow_prop_data', 'freq_cbins', 'SOpow_cbins', 'subjects',...
    'issz', 'electrodes', '-v7.3');






