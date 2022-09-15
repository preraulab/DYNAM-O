%%%% Example script showing how to compute time-frequency peaks and SO-power/phase histograms
%% PREPARE DATA
%Clear workspace and close plots
clear; close all; clc;

%% SETTINGS
%Select 'segment' or 'night' for example data range
data_range = 'night'; 
HR_spect_settings = "paper"; 

%% PREPARE DATA
%Check for parallel toolbox
v = ver;
haspar = any(strcmp({v.Name}, 'Parallel Computing Toolbox'));
if haspar
    gcp;
end

%Load example EEG data
load('example_data/example_data.mat', 'EEG', 'stage_vals', 'stage_times', 'Fs');

%STAGE NOTATION (in order of sleep depth)
% W = 5, REM = 4, N1 = 3, N2 = 2, N1 = 1, Artifact = 6, Undefined = 0

% Add necessary functions to path
addpath(genpath('./toolbox'))

switch data_range
    case 'segment'
        % Pick a segment of the spectrogram to extract peaks from
        % Choose an example segment from the data
        time_range = [8420 13446]; %[10000, 10100]; 
        output_fname = 'toolbox_example_segment.png';
        disp('Running example segment')
    case 'night'
        wake_buffer = 5*60; %5 minute buffer before/after first/last wake
        start_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'first')) - wake_buffer;
        end_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'last')+1) + wake_buffer;

        time_range = [start_time end_time];

        output_fname = 'toolbox_example_fullnight.png';
        disp('Running full night')
end

% Downsample settings
downsample_spect1 = [1,2,3,4,5];
downsample_spect2 = [1,2,3,4,5];
num_iters = length(downsample_spect1) * length(downsample_spect2);

load('./archive/papersettings_peakprops_fullnight.mat');
SOpowhist_paper = SOpow_mat;
SOphasehist_paper = SOphase_mat;

RMSE_pow = nan(num_iters, 1);
RMSE_phase = nan(num_iters,1);
timetaken = nan(num_iters, 1);
npeaks = nan(num_iters, 1);
LR_spect_settings_all = nan(num_iters, 3);

count = 0;
for w = 1:length(downsample_spect1)
    for d = 1:length(downsample_spect2)
        count = count + 1;

        %Spectral settings for computing watershed
        LR_spect_settings = [1, 0.05*downsample_spect1(w), 0.1*downsample_spect2(d)]; 
        
        %% RUN WATERSHED AND COMPUTE SO-POWER/PHASE HISTOGRAMS
        tic;
        [peak_props, SOpow_mat, SOphase_mat, SOpow_bins, SOphase_bins, freq_bins, spect, stimes, sfreqs, SOpower_norm, SOpow_times, boundaries] = run_watershed_SOpowphase(EEG, Fs, stage_times, stage_vals, 'time_range', time_range, 'downsample_spect', [downsample_spect1(w), downsample_spect2(d)], 'spect_settings', HR_spect_settings);
        timetaken(count) = toc;
        RMSE_pow(count) = sqrt(mean( (SOpowhist_paper-SOpow_mat).^2 , 'all', 'omitnan'));
        RMSE_phase(count) = sqrt(mean( (SOphasehist_paper-SOphase_mat).^2 , 'all', 'omitnan'));
        npeaks(count) = height(peak_props);
        LR_spect_settings_all(count,:) = LR_spect_settings;
    end
    save('RMSE_time_outdata.mat', 'RMSE_pow', 'RMSE_phase', 'timetaken', 'LR_spect_settings_all');
end


