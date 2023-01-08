% ccc
% load peaks_computed.mat;

%%
nanEEG = data;
nanEEG(artifacts) = nan;

% Compute SO power in dB
SO_freqrange = [.3 1.5];
[SOpower, SOpower_times] = computeMTSpectPower(nanEEG, Fs, 'freq_range', SO_freqrange);
SOpower_times = SOpower_times + t_data(1);

% Exclude outlier SOpower that usually reflect artifacts
SOpower(abs(nanzscore(SOpower)) >= 3) = nan;

% Compute stages
SOpow_stages = interp1(stage_times, double(stage_vals), SOpower_times,'previous');

%Normalize to p2 of sleep
norm_stages = 1; %N1-N3 + REM
ptile = 2;

norm_stage_inds = ismember(SOpow_stages, norm_stages);
shift = prctile(SOpower(norm_stage_inds), ptile);
SOpower_norm = SOpower - shift;

%Include only NREM in analysis
SOPH_stages= 1:3;
SOpower_norm(~ismember(SOpow_stages, SOPH_stages)) = nan;

SOpower_range = [-10 20];
SOpower_binsizestep = [5 .1];
freq_range = [4 25];
freq_binsizestep = [1 .1];
min_time_in_bin = 5;
dim_normalize = [];
rate_flag = false;
smooth_flag = false;
plot_flag = true;


TFPeakHistogram(SOpower_norm, SOpower_times, stats_table.PeakFrequency, stats_table.PeakTime, freq_range, freq_binsizestep, ...
                                     SOpower_range, SOpower_binsizestep,  ...
                                     min_time_in_bin, dim_normalize, ...
                                     rate_flag, smooth_flag, plot_flag);

stage_names = ["N3", "N2", "N1","REM", "Wake"];

title(['Ptile stages: ' sprintf('%s ', stage_names(norm_stages)) 'shift = -' num2str(shift)]);

