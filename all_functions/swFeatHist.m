function [SWF_hists, swf_bins, freqs, time_in_swf_bin, stage_time, total_time, count_mismatch_bin_times] = swFeatHist(eegdata, Fs, peak_freqs, peak_times, pick_sleep_times, ...
                                                                                                                     stage_struct, swfeat, units, normalize, num_swf_bins, ...
                                                                                                                     select_stages, time_in_bin, freq_df, window_size, window_step_size,...
                                                                                                                     filter, spect_data, f_lightsout, ploton)
% Modified:
%   20210908 -- added time_in_bin input to give ability to change required
%               time in SO bin for column of hist to be computed
%   20210716 -- added filter param for precomputed filter and spect_data for precomputed spectrogram (Tom P)
%   20190424 -- Forked from swFeatHistogram. Cleaned up for toolbox.
%   20181210 -- Changed bin edge handling. Now uses equality at left edge and
%            inequality at right, except at end where both are inclusive.
%   20180830 -- Changed to try to make more readable.
%            *Changed to correctly match sorting
%   20180829 -- File processing and loading was moved outside to
%            compute_swfeat_histograms.m. The inputs were updated
%            accordingly. total_time now returned as an output.
%


% Handle nargin
if nargin<19
    ploton = [];
end

if nargin<18
    f_lightsout = [];
end

if nargin<17
    spect_data = [];
end

if nargin<16
    filter = [];
end

if nargin<15
    window_step_size = [];
end

if nargin<14
    window_size = [];
end

if nargin < 13
    freq_df = [];
end 

if nargin<12
    time_in_bin = [];
end

if nargin<11
    select_stages = [];
end

if nargin<10
    num_swf_bins = [];
end

if nargin<9
    units = [];
end

if nargin<8
    normalize = [];
end

if nargin<7
    swfeat = [];
end

if nargin<6
    stage_struct = [];
end

if nargin<5
    pick_sleep_times = [];
end

% Set defaults
if isempty(ploton)
    ploton = false;
end

if isempty(f_lightsout)
    f_lightsout = false;
end

if isempty(select_stages)
    select_stages = 1:5;
end

if isempty(freq_df)
    freq_df = 0.1;
end

if isempty(time_in_bin)
    time_in_bin = 1; % minutes
end

if isempty(units)
    units = 'dB';
end

if isempty(normalize)
    normalize = 'absolute';
end

if isempty(swfeat)
    swfeat = 'power';
end

if isempty(pick_sleep_times)
    pick_sleep_times = true(length(peak_times),1);
end

% Initialize outputs in case of early return
% SWF_hists = [];
% SWF_bins = [];
% freqs = [];
% SWF_time_in_bin = [];
% stage_prop = [];

% Define the frequency range
min_freq = 0;
max_freq = 40;
freqs = min_freq:freq_df:max_freq;
F = length(freqs);

%Compute the SWP for the given electrode
switch lower(swfeat)
    case 'power'
        [eeg_swf, eeg_swf_times] = compute_SWA(eegdata, Fs, units, spect_data);
        dtS = eeg_swf_times(2)-eeg_swf_times(1);
    case 'phase'
        [eeg_swf, eeg_swf_times] = compute_SWPhase(eegdata, Fs, 'hilbert', filter);
        eeg_swf = eeg_swf';
        dtS = eeg_swf_times(2)-eeg_swf_times(1);
end

%Remove any bad values
pick_good_eeg_swf = ~isnan(eeg_swf) & ~isinf(eeg_swf);
eeg_swf = eeg_swf(pick_good_eeg_swf);
eeg_swf_times = eeg_swf_times(pick_good_eeg_swf);

% Indicator of lightsout and stages for raw EEG
eegtimes = (1:length(eegdata))/Fs;
if ~isempty(stage_struct)
    % In next line, [1:4] is used (instead of select_stages) to only use artifact-free sleep
    % of eeg data for the power percentiles. It does NOT subselect peaks. 
    pick_eegrawstages = findStageIndices(eegtimes',stage_struct,[1:4]); % select_stages
    if f_lightsout
        t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
        t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;
        pick_eegrawlightsout = eegtimes'>=t_lightsout & eegtimes'<=t_lightson;
        pick_eegrawstages = pick_eegrawstages & pick_eegrawlightsout;
    end
else
    pick_eegrawstages = true(size(eegtimes'));
end

% Indicator of lightsout and stages for EEG SWF
if ~isempty(stage_struct)
    pick_eegswfstages = findStageIndices(eeg_swf_times',stage_struct,select_stages);
    if f_lightsout
        t_lightsout = min(stage_struct.time(stage_struct.stage~=5))-5*60;
        t_lightson = max(stage_struct.time(stage_struct.stage~=5))+5*60;
        pick_eeglightsout = eeg_swf_times'>=t_lightsout & eeg_swf_times'<=t_lightson;
        pick_eegswfstages = pick_eegswfstages & pick_eeglightsout;
    end
else
    pick_eegswfstages = true(size(eeg_swf_times'));
end

%Handle the normalization
switch lower(swfeat)
    case 'power'
        switch lower(normalize)
            case {'percentile','ptile','%ile'} %Percentile normalization
                %Compute the percentiles of each point in the SWP
                [~,sort_inds] = sort(eeg_swf);
                eeg_swf(sort_inds) = (0:length(eeg_swf)-1)/length(eeg_swf);
                
                hist_swf_max = 1;
                hist_swf_min = 0;
                if isempty(window_size)
                    window_size = .05;
                end
                if isempty(window_step_size)    
                    window_step_size = .01;
                end
            case {'percent','%'} %SWP% normalization
                low_val = 2.5;
                high_val = 95;
                
                p_low = prctile(eeg_swf,low_val);
                p_high = prctile(eeg_swf,high_val);
                
                %Scale between 5th and 95th percentiles
                eeg_swf(eeg_swf<p_low) = p_low;
                eeg_swf(eeg_swf>p_high) = p_high;
                eeg_swf = eeg_swf-p_low;
                eeg_swf = eeg_swf/max(eeg_swf);
                
                hist_swf_max = 1;
                hist_swf_min = 0;
                
                if isempty(window_size)
                    window_size = .05;
                end
                if isempty(window_step_size)    
                    window_step_size = .01;
                end
            case {'percentsleep','percent sleep','%sleep'} %SWP% normalization
                pick_stage_lo= find_stage_indices(eeg_swf_times',stage_struct,[3 4]);
                pick_stage_hi= find_stage_indices(eeg_swf_times',stage_struct,[1:2]);
                low_val = 2.5;
                high_val = 97.5;
                
                p_low = prctile(eeg_swf(pick_stage_lo),low_val);
                p_high = prctile(eeg_swf(pick_stage_hi),high_val);
                
                %Scale between 5th and 95th percentiles
                eeg_swf(eeg_swf<p_low) = p_low;
                eeg_swf(eeg_swf>p_high) = p_high;
                eeg_swf = eeg_swf-p_low;
                eeg_swf = eeg_swf/max(eeg_swf);
                
                hist_swf_max = 1;
                hist_swf_min = 0;
                
                if isempty(window_size)
                    window_size = .05;
                end
                if isempty(window_step_size)    
                    window_step_size = .01;
                end
            case {'percentnoartifact'} %SWP% normalization
                low_val = .1;
                high_val = 99.9;
                num_std = 3;
                [processed_ptiles, ~] = SW_percentiles_artifact_rejected(eegdata(pick_eegrawstages), Fs, [low_val high_val], num_std, units);
                p_low = processed_ptiles(1); 
                p_high = processed_ptiles(2);
                
                %Scale between 5th and 95th percentiles
%                 eeg_swf(eeg_swf<p_low) = p_low;
%                 eeg_swf(eeg_swf>p_high) = p_high;
                eeg_swf = eeg_swf-p_low;
                eeg_swf = eeg_swf/(p_high-p_low);
                
                hist_swf_max = 1;
                hist_swf_min = 0;
                
                if isempty(window_size)
                    window_size = .05;
                end
                if isempty(window_step_size)    
                    window_step_size = .01;
                end
            case {'percentlightsoutnoartifact'} %SWP% normalization
                low_val =  .1;
                high_val =  99.9;
                num_std = 5;
                [processed_ptiles, ~] = SW_percentiles_artifact_rejected(eegdata(pick_eegrawstages), Fs, [low_val high_val], num_std, units);
                p_low = processed_ptiles(1); 
                p_high = processed_ptiles(2);
                
                %Scale between 5th and 95th percentiles
%                 eeg_swf(eeg_swf<p_low) = p_low;
%                 eeg_swf(eeg_swf>p_high) = p_high;
                eeg_swf = eeg_swf-p_low;
                eeg_swf = eeg_swf/(p_high-p_low);
                
                hist_swf_max = 1;
                hist_swf_min = 0;
                
                if isempty(window_size)
                    window_size = .05;
                end
                if isempty(window_step_size)    
                    window_step_size = .01;
                end
            case {'shift'} 
                low_val =  5; % 0.1
                high_val =  99.9;
                num_std = 5;
                [processed_ptiles, ~] = SW_percentiles_artifact_rejected(eegdata(pick_eegrawstages), Fs, [low_val high_val], num_std, units);
                p_low = processed_ptiles(1); 
                p_high = processed_ptiles(2);
                
                eeg_swf = eeg_swf-p_low;
                
                hist_swf_max = 40; % 30; % 
                hist_swf_min = 0;
                
                if isempty(window_size)
                    window_size = .05;
                end
                if isempty(window_step_size)    
                    window_step_size = .01;
                end
            case {'abs','absolute','none'} %Handle absolute case
                %Adjust window sizing based on power units
                if strcmpi(units,'dB')
                    hist_swf_max = 50;
                    hist_swf_min = 10; % 15; % 
                    
                    window_size = 1; % original is 1.5 
                    window_step_size = .1;
                else
                    hist_swf_max = 150;
                    hist_swf_min = 0;
                    
                if isempty(window_size)
                    window_size = 5;
                end
                if isempty(window_step_size)    
                    window_step_size = 1;
                end
                end
            otherwise
                error('Invalid normalization');
        end
    case 'phase'
        hist_swf_min = -pi;
        hist_swf_max = pi;
        if isempty(window_size)
            window_size = 1;
        end
        if isempty(window_step_size)    
            window_step_size = .05;
        end    
end

if ~isempty(num_swf_bins)
    window_step_size = (hist_swf_max-window_size-hist_swf_min)/(num_swf_bins-1);
end

%Interpolate to get the SWP at the peak times
[peak_times_sorted, sort_ind] = sort(peak_times);
peak_swf_interp = interp1(eeg_swf_times, eeg_swf, peak_times_sorted);
if strcmpi(swfeat,'phase')
    eeg_swf = mod(eeg_swf,2*pi)-pi;
    peak_swf_interp = mod(peak_swf_interp,2*pi)-pi;
end
%****
% peak_swf_interp(sort_ind) = peak_swf_interp;
peak_freqs = peak_freqs(sort_ind);
pick_sleep_times = pick_sleep_times(sort_ind);
%****

%Window start indices
bin_edges_l = hist_swf_min:window_step_size:hist_swf_max-window_size;
bin_edges_r = min(bin_edges_l+window_size,hist_swf_max);
%The bin centers
swf_bins = (bin_edges_l + bin_edges_r)/2;
% swf_bins = hist_swf_min:window_step_size:hist_swf_max;
% bin_edges_l = max(swf_bins-window_size/2,hist_swf_min);
% bin_edges_r = min(swf_bins+window_size/2,hist_swf_max);

%Number of bins
N = length(bin_edges_l);

%Matrix of histograms
SWF_hists = nan(N,F);

stage_time = zeros(N,5);
time_in_swf_bin = zeros(N,1);

%Compute the SWP histogram
total_time = sum(eeg_swf>=bin_edges_l(1) & eeg_swf<=bin_edges_r(end))*dtS/60;

count_mismatch_bin_times = 0;
for ii=1:N
    %Compute window index
    if ii==N
        pick_swf_in_bin = peak_swf_interp>=bin_edges_l(ii) & peak_swf_interp<=bin_edges_r(ii);
        pick_eegswf_in_bin = eeg_swf>=bin_edges_l(ii) & eeg_swf<=bin_edges_r(ii);
    else
        pick_swf_in_bin = peak_swf_interp>=bin_edges_l(ii) & peak_swf_interp<bin_edges_r(ii);
        pick_eegswf_in_bin = eeg_swf>=bin_edges_l(ii) & eeg_swf<bin_edges_r(ii);
    end
    pick_swf_in_bin = pick_swf_in_bin & pick_sleep_times;
    pick_eegswf_in_bin = pick_eegswf_in_bin & pick_eegswfstages;
    
    if ~isempty(stage_struct)
        if ii == 1
            pick_eegswf_in_bin_last = zeros(length(pick_eegswf_in_bin),1);
        end
        % Get eeg_swf times that are specific to only current bin (bins overlap)
        eeg_swf_times_in_bin_nonoverlap = eeg_swf_times(((pick_eegswf_in_bin|pick_eegswf_in_bin_last)+pick_eegswf_in_bin)==1)';
        eeg_swf_stages = interp1(stage_struct.time, stage_struct.stage, eeg_swf_times_in_bin_nonoverlap, 'previous');
        
        for ss = 1:5
            stage_time(ii,ss) = sum(eeg_swf_stages==ss)*dtS;
        end

    end
    
    time_in_swf_bin(ii)= sum(pick_eegswf_in_bin)*dtS/60;
    
    if (length(eeg_swf_times_in_bin_nonoverlap)*dtS) ~= sum(stage_time(ii,:))
        if abs((length(eeg_swf_times_in_bin_nonoverlap)*dtS) - sum(stage_time(ii,:))) > 0.5
            keyboard;
        end
        count_mismatch_bin_times = count_mismatch_bin_times + 1;
    end
    
    pick_eegswf_in_bin_last = pick_eegswf_in_bin;

    
    switch lower(swfeat)
        case 'power'
            %Compute histogram and convert to rate (events/min)
            if any(pick_swf_in_bin) &&  time_in_swf_bin(ii)>time_in_bin
                SWF_hists(ii,:) = smooth(hist(peak_freqs(pick_swf_in_bin),freqs));
                %Do rate as events/min
                SWF_hists(ii,:) = SWF_hists(ii,:)./ time_in_swf_bin(ii);
            end
        case 'phase'
            if any(pick_swf_in_bin) % & time_in_SWP_bin>5
                SWF_hists(ii,:) = smooth(hist(peak_freqs(pick_swf_in_bin),freqs));
                SWF_hists(ii,:) = SWF_hists(ii,:)./total_time;
            end 
    end
    
    
end

if strcmpi(swfeat,'phase') && strcmpi(normalize,'perSubj')
    SWF_hists = SWF_hists ./repmat(sum(SWF_hists,1),[length(swf_bins) 1]);
end

% if ~isempty(stage_struct)
%     stage_prop = stage_prop./repmat(sum(stage_prop,2),1,5);
% end

%***
% PLOT RESULTS
%***
if ploton
    figure
    imagesc((swf_bins),freqs,(SWF_hists'))
    climscale([],[],false)
    xlabel(['SW ' upper(swfeat)]);
    ylabel('Frequency (Hz)');
    axis xy;
    ylim([0 40]);
    title(['Peak Frequency Distribution as a Function of SW ' upper(swfeat)]);
    % suptitle(subject)
    drawnow
end
end
