clear;
%addpath(genpath('C:\Users\Work_Tom\Desktop\Lab_Code\Github\utils'));

%% Load Peak Data and Hists
load('papersettings_peakprops_fullnight.mat');
peak_props_paperset = peak_props;
SOpow_paperset = SOpow_mat;
SOphase_paperset = SOphase_mat;

load('peakprops_fullnight_downsample2.mat');
peak_props_downs = peak_props;
SOpow_downs = SOpow_mat;
SOphase_downs = SOphase_mat;

load('peakprops_fullnight_downsample2_bilinear.mat');
peak_props_fast = peak_props;
SOpow_fast = SOpow_mat;
SOphase_fast = SOphase_mat;

peak_props_all = {peak_props_paperset, peak_props_fast, peak_props_downs};
peak_prop_strs = {'peak_freqs', 'peak_height', 'peak_bw', 'peak_dur'};
titles = {'Peak Frequency', 'Peak Prominence', 'Peak Bandwidth', 'Peak Duration'};
ylabs = {'Paper Settings', 'Downsampled 2x2', 'Downsampled Bilinear'};
ylim_list = {[0,3000], [0,13000], [0, 5500], [0,3800]};
xlim_list = {[0,30], [0,250], [0,15], [0,5]};
%% Plot Peak Prop Hists
fh1 = figure;
ax = figdesign(3,4);
count = 0;
for m = 1:3
    peak_props = peak_props_all{m};
    for p = 1:4
        count = count + 1;
        axes(ax(count));
        histogram(peak_props{:,ismember(peak_props.Properties.VariableNames,peak_prop_strs{p})});
        ylim(ylim_list{p});
        xlim(xlim_list{p});
        if m==1
            title(titles{p});
        end
        if p == 1
            ylabel(ylabs{m});
        end
    end
end

%% Calc SOpow/phase MSE
MSE_paperfast_pow = sqrt(mean( (SOpow_paperset - SOpow_fast).^2, 'all', 'omitnan'));
MSE_paperfast_phase = sqrt(mean( (SOphase_paperset - SOphase_fast).^2, 'all', 'omitnan'));

MSE_paperds_pow = sqrt(mean( (SOpow_paperset - SOpow_downs).^2, 'all', 'omitnan'));
MSE_paperds_phase = sqrt(mean( (SOphase_paperset - SOphase_downs).^2, 'all', 'omitnan'));

