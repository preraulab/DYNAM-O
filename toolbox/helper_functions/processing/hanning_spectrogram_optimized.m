function [hann_spectrogram,stimes,sfreqs] = hanning_spectrogram_optimized(varargin)
%HANNING_SPECTROGRAM  Compute the spectrogram for time series data with Hanning windowing
%
%   Usage:
%   Direct input:
%       [spect,stimes,sfreqs] = hanning_spectrogram_optimized(data, Fs, event_times, frequency_range, window_params, nfft, detrend_opt, plot_on, mts_verbose);
%
%   Input:
%       data: <number of samples> x 1  vector - time series data-- required
%       Fs: double - sampling frequency in Hz  -- required
%       event_times - 1xN vector with a time for each peak -- required
%       t: double - <number of samples> x 1  vector timestamps for data. Default = (0:length(data)-1)/Fs;
%       frequency_range: 1x2 vector - [<min frequency>, <max frequency>] (default: [0 nyquist])
%       window_params: 1x2 vector - [window size (seconds), step size (seconds)] (default: [5 1])
%       nfft: double - NFFT size, adds zero padding for interpolation (closest 2^x) (default: 0)
%       detrend_opt: string - detrend data window ('linear' (default), 'constant', 'off');
%       plot_on: boolean to plot results (default: true)
%       verbose: boolean to display spectrogram properties (default: true)
%       xyflip: boolean to flip spectrogram (default: false)
%
%   Output:
%       spect: FxT matrix of spectral power
%       stimes: 1xT vector of times for the center of the spectral bins
%       sfreqs: 1xF vector of frequency bins for the spectrogram
%
%    Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%    Authors: Michael J. Prerau, Ph.D., Mingjian He
%
%% ********************************************************************

% PROCESS DATA AND PARAMETERS

%Process user input
p = inputParser;
addRequired(p,'data', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p,'Fs', @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addRequired(p,'event_times',@(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p,'t',[], @(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));
addOptional(p,'frequency_range',[], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonan'}));
addOptional(p,'data_window_params',[5,1],@(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'nonempty'}));
addOptional(p,'NFFT',0,@(x) validateattributes(x, {'numeric', 'scalar'}, {'real', 'nonempty'}));
addOptional(p,'detrend_opt','linear',@(x) validateattributes(x,{'logical','char','string'},{'real','nonempty'}));
addOptional(p,'plot_on',true,@(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p,'verbose',true,@(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
addOptional(p,'xyflip',false,@(x) validateattributes(x,{'logical'},{'real','nonempty', 'nonnan'}));
parse(p,varargin{:});

[data, Fs, frequency_range, winsize_samples, winstep_samples, window_start, num_windows, nfft, detrend_opt, ...
    plot_on, verbose, xyflip] = process_input(p);

%Set up and display spectrogram parameters
[window_idxs, stimes, sfreqs, freq_inds] = get_windows(Fs, nfft, frequency_range, window_start, winsize_samples);

if verbose
    display_spectrogram_props([winsize_samples winstep_samples], frequency_range, detrend_opt, Fs);
end

%Preallocate spectrogram and slice data for efficient parallel computing
data_type = class(data);
hann_spectrogram = zeros(sum(freq_inds), num_windows, data_type);
data_segments = data(window_idxs)';

%Start timing
start_time = datetime('now');

%% COMPUTE THE HANN SPECTROGRAM
%
%     STEP 1: Compute hann taper based on desired spectral properties
%     STEP 2: Multiply the data segment by the hann Taper
%     STEP 3: Compute the spectrum for each tapered segment

hann_taper = hann(winsize_samples);
hann_taper = hann_taper / sqrt(sum(hann_taper.^2));

%Loop in parallel over all of the windows
parfor n = 1:num_windows % REMOVE PARFOR TO TEST
    %Grab the data for the given window
    data_segment = data_segments(:,n);
    
    %Skip empty segments
    if all(data_segment == 0)
        continue;
    end
    
    if any(isnan(data_segment))
        hann_spectrogram(:,n) = nan;
        continue;
    end
    
    %Option to detrend_opt data to remove low frequency DC component
    if detrend_opt
        data_segment = detrend(data_segment, detrend_opt);
    end
    
    %Multiply the data by the hann taper
    tapered_data = data_segment.* hann_taper;
    
    %Compute the FFT
    fft_data = fft(tapered_data, nfft);
    
    %Compute spectral power
    h_spectrum = imag(fft_data).^2 + real(fft_data).^2;
        
    %Add the spectrum to the spectrogram
    hann_spectrogram(:,n) = h_spectrum(freq_inds);
end


%Compute one-sided PSD spectrum 
DC_select = find(sfreqs==0);
Nyquist_select = find(sfreqs==Fs/2);
select = setdiff(1:length(sfreqs), [DC_select, Nyquist_select]);
hann_spectrogram = [hann_spectrogram(DC_select,:); 2*hann_spectrogram(select,:); hann_spectrogram(Nyquist_select,:)] / Fs;

%Flip if requested
if xyflip; hann_spectrogram = hann_spectrogram'; end


%% PLOT THE SPECTROGRAM

%Show timing if verbose
if verbose
    disp(' ');
    disp(['Estimation time: ' char(datetime('now') - start_time)]);
end

%Plot the spectrogram
if plot_on
    if xyflip
        imagesc(stimes, sfreqs, nanpow2db(hann_spectrogram'));
    else
        imagesc(stimes, sfreqs, nanpow2db(hann_spectrogram));
    end
    axis xy
    
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    
    climscale; 
    c = colorbar_noresize;
    ylabel(c,'Power (dB)');
    
    axis tight
end

end



% ********************************************
%           HELPER FUNCTIONS
% ********************************************
%% PROCESS THE USER INPUT

function [data, Fs, frequency_range, winsize_samples, winstep_samples, window_start, num_windows, nfft, ...
          detrend_opt, plot_on, verbose, xyflip,flag] = process_input(p)
% Manually assign variables because eval doesn't work with parpool
data = p.Results.data;
Fs = p.Results.Fs;
event_times = p.Results.event_times;
t = p.Results.t;
frequency_range = p.Results.frequency_range;
data_window_params = p.Results.data_window_params;
NFFT = p.Results.NFFT;
detrend_opt = p.Results.detrend_opt;
plot_on = p.Results.plot_on;
verbose = p.Results.verbose;
xyflip = p.Results.xyflip;
% Set defaults
if isempty(t)
    t = (0:length(data)-1)/Fs;
end
if isempty(frequency_range)
    frequency_range = [0 Fs/2];
end
if NFFT ==0
   NFFT = 2^(nextpow2(data_window_params(1)*Fs)); 
end 
%Set either linear or constant detrending
if detrend_opt ~= false
    switch lower(detrend_opt)
        case {'const','constant'}
            detrend_opt = 'constant';
        case {'none', 'off'}
            detrend_opt = false;
        otherwise
            detrend_opt = 'linear';
    end
end
%Fix error in frequency range
if length(frequency_range) == 1 %Set max frequency to nyquist if only lower bound specified
    frequency_range(2) = Fs/2;
elseif frequency_range(2) > Fs/2 % updated on 05/18/2020 to remove floor on (Fs/2)
    frequency_range(2) = Fs/2;
    warning(['Upper frequency range greater than Nyquist, setting range to [' num2str(frequency_range(1)) ' ' num2str(frequency_range(2)) ']']);
end

%Compute the data window and step size in samples
if mod(data_window_params(1)*Fs,1)
    winsize_samples=round(data_window_params(1)*Fs);
    warning(['Window size is not clearly divisible by sampling frequency. Adjusting window size to ' num2str(winsize_samples/Fs) ' seconds']);
else
    winsize_samples=data_window_params(1)*Fs;
end

flag = 0;
if mod(data_window_params(2)*Fs,1)
    winstep_samples=round(data_window_params(2)*Fs);
    flag = 1;
    warning(['Window step size is not clearly divisible by sampling frequency. Adjusting window size to ' num2str(winstep_samples/Fs) ' seconds']);
else
    winstep_samples=data_window_params(2)*Fs;
end

%Force data to be a column vector 
if isrow(data)
    data = data(:);
end

% Find index in the full signal where each window starts
window_start = event_times - t(1)- data_window_params(1)/2; %seconds
window_start = floor(window_start*Fs)'; % indices
assert(all(window_start>0), 'Negative or 0 window start indices')

%Number of windows
num_windows = length(window_start);

%Number of points in the FFT
nfft = 2^(nextpow2(NFFT)); %max(max(2^(nextpow2(winsize_samples)),winsize_samples), 2^nextpow2(NFFT));
end

%% PROCESS THE SPECTROGRAM PARAMETERS

function [window_idxs, stimes, sfreqs, freq_inds] = get_windows(Fs, nfft, frequency_range, window_start, datawin_size)
%Create the frequency vector
df = Fs/nfft;
sfreqs = 0:df:Fs; % all possible frequencies

%Get just the frequencies for the given frequency range
freq_inds = (sfreqs >= frequency_range(1)) & (sfreqs <= frequency_range(2));
sfreqs = sfreqs(freq_inds);

%Compute the times of the middle of each spectrum
window_middle_samples = window_start + round(datawin_size/2);
stimes = (window_middle_samples-1)/Fs; % stimes start from 0

%Data windows
window_idxs = window_start' + (0:datawin_size-1);

end

%% DISPLAY SPECTROGRAM PROPERTIES

function display_spectrogram_props(data_window_params, frequency_range, detrend_opt, Fs)
data_window_params = data_window_params/Fs;
%my_pool = gcp;
if detrend_opt
    det_string=lower(detrend_opt);
    det_string(1) = upper(det_string(1));
else
    det_string='Off';
end

% Display spectrogram properties
disp(' ');
disp('Hanning Spectrogram Properties:');
disp(' ');
disp(['    Spectral Resolution: ' num2str(data_window_params(1)/4) 'Hz']);
disp(['    Window Length: ' num2str(data_window_params(1)) 's']);
disp(['    Window Step: ' num2str(data_window_params(2)) 's']);
disp(['    Frequency Range: ' num2str(frequency_range(1)) 'Hz - ' num2str(frequency_range(2)) 'Hz']);
disp(['    Detrending: ' det_string]);
disp(' ');
%disp(['Estimating hanning spectrogram on ' num2str(my_pool.NumWorkers) ' workers...']);
end

function ydB = nanpow2db(y)
%POW2DB   Power to dB conversion, setting all bad values to nan
%   YDB = POW2DB(Y) convert the data Y into its corresponding dB value YDB
%
%   % Example:
%   %   Calculate ratio of 2000W to 2W in decibels
%
%   y1 = pow2db(2000/2)     % Answer in db

%   Copyright 2006-2014 The MathWorks, Inc.
% EDITED BY MJP 2/7/2020

%#codegenr
% cond = all(y(:)>=0);
% if ~cond
%     coder.internal.assert(cond,'signal:pow2db:InvalidInput');
% end

%ydB = 10*log10(y);
%ydB = db(y,'power');
% We want to guarantee that the result is an integer
% if y is a negative power of 10.  To do so, we force
% some rounding of precision by adding 300-300.

ydB = (10.*log10(y)+300)-300;
ydB(y(:)<=0) = nan;
end
