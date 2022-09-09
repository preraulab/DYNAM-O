ccc; 

%% Load Example data and compute high-res spectrogram 
load('example_data/example_data.mat')
time_range = [10000, 10100]; %[8420 13446]; 

[spect,stimes,sfreqs] = multitaper_spectrogram_mex(EEG, Fs, [0,30], [2,3], [1,0.05], 2^(nextpow2(Fs/0.1)), 'off', 'unity', false);

% wake_buffer = 5*60; %5 minute buffer before/after first/last wake
% start_time = stage_times(find(stage_vals < 5 & stage_vals > 0, 1, 'first')) - wake_buffer;

[~,start] = min(abs(time_range(1) - stimes));
[~,last] = min(abs(time_range(2) - stimes));
spect_in = spect(:, start:last);
stimes_in = stimes(start:last);


%% Load boundary data

load('boundaries_noupdates_papersettings.mat', 'boundaries');
bounds_paper = boundaries;
load('boundaries_noupdates_fastsettings.mat', 'boundaries');
bounds_fast = boundaries;
load('boundaries_noupdates_draftsettings.mat', 'boundaries');
bounds_draft = boundaries;



figure;
imagesc(stimes_in, sfreqs, nanpow2db(spect_in));
axis xy;
colormap jet;
climscale;

hold on;
for ii = 1:length(bounds_paper)
    bounds_paper{ii}(:,2) = bounds_paper{ii}(:,2);
    if all((bounds_paper{ii}(:,2) <= time_range(2)) & (bounds_paper{ii}(:,2) >= time_range(1)))
        plot(bounds_paper{ii}(:,2), bounds_paper{ii}(:,1), 'color', 'g', 'linewidth',2);
    end
end

hold on;
for ii = 1:length(bounds_fast)
    bounds_fast{ii}(:,2) = bounds_fast{ii}(:,2);
    if all((bounds_fast{ii}(:,2) <= time_range(2)) & (bounds_fast{ii}(:,2) >= time_range(1)))
        plot(bounds_fast{ii}(:,2), bounds_fast{ii}(:,1), 'color', 'm', 'linewidth',1);
    end
end

hold on;
for ii = 1:length(bounds_draft)
    bounds_draft{ii}(:,2) = bounds_draft{ii}(:,2);
    if all((bounds_draft{ii}(:,2) <= time_range(2)) & (bounds_draft{ii}(:,2) >= time_range(1)))
        plot(bounds_draft{ii}(:,2), bounds_draft{ii}(:,1), 'color', 'k', 'linewidth',1);
    end
end



