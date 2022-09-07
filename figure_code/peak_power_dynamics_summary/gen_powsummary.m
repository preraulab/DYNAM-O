ccc

% Histogram Rebinning Params
freq_binsizestep = [1, 0.2]; % orig: [0.5, 0.1] standard: [1, 0.2] 6x6: [2.35, 2.35]
SOpow_binsizestep = [0.2, 0.01]; % orig: [0.05, 0.01]  standard: [0.2, 0.01] 6x6: [0.165, 0.165]
SOphase_binsizestep = [(2*pi)/5, (2*pi)/100]; % orig: [(2*pi)/(400/67), (2*pi)/(400/3)] standard: [(2*pi)/5, (2*pi)/100] 6x6: [(2*pi)/(400/67), (2*pi)/(400/67)]

freq_range = [4,25]; % Hz

load('SO_power_example_data.mat');


fwindow_size = freq_binsizestep(1);
SOpow = SOpower_norm;
SOpow_times = SOpower_times;
SOpow_hist = powhist;
SOpow_bins = SOpow_cbins;
SOpow_freqs = freq_cbins;
time_window = [60*10 15];
stage_prop = PIB_allstages;
peak_times = peak_data(:,2);
peak_proms = peak_data(:,5);
peak_freqs = peak_data(:,4);


power_dynamics_summary(data, stages, stage_prop, Fs, freq_range, SOpow, SOpow_times, SOpow_hist, SOpow_bins, SOpow_freqs,...
    peak_freqs, peak_times, peak_proms, time_window, fwindow_size);

