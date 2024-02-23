function [ fpeak_proms, fpeak_freqs, fpeak_bandwidths, fpeak_bandwidth_bounds, normalized_spectrogram ] = find_frequency_peaks(spect,stimes,sfreqs,varargin)
%
% **PEAK PROMINENCE CALCULATION IN THE FREQUENCY DOMAIN**
%&#x1F536;
%
% function used to calculate the peak prominence of the spectrum at each
% point in a spectrogram. Works by looking for activity in the designated
% frequency range. Normalizes the frequency values by dividing by a
% percentile of the the spectral values. The percentile can be calculated
% from a full night (artifact/wake-free sleep) or from a local segment with
% length of X minutes. By default, no normalization is applied since the
% prominence extraction implicitly takes care of the slow trend in the
% frequency domain.
%
% Usage: [ fproms, ffreq, fwidth, x_fwidth, normalized_spectrogram ] = find_frequency_peaks(spectrogram,stimes,sfreqs,valid_time_inds,'<flag#1>',<arg#1>...<flag#n>',<arg#n>);
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Declared Inputs: [[[NEEDS UPDATES!!!]]]
%
%       The following variables can be generated from the
%       multitaper_spectrogram function:
%
%           - scube:        The spectrum at each time point. Format( Time X Frequency X Channels);
%
%           - stimes:       The time step vectors as defined by the mutlitaper
%                           spectrogram parameters.
%
%           - sfreqs:       The frequency step vector as defined by the mutlitaper
%                           spectrogram parameters.
%
%       Other Parameters:
%
%           - stages:       The sleep stages as a vector.
%
%           - epochsize:    The epochsize at which the stages were scored.
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Optional Inputs:
%
%           - 'norm_method':        A string specifying what normalization
%                                   method to use. Can be 'percentile',
%                                   'detrend', or 'none' (default).
%                                   default: 'none'
%           - 'norm_time_inds':     Indices of time points to include in
%                                   the normalization. Disabled for now
%                                   since 'norm_method' is set to 'none'.
%                                   default: true(1, length(stimes))
%
%           - 'peak_freq_range':    The range of frequencies to look for
%                                   peak prominence values within.
%                                   default: [9, 17]
%
%           - 'findpeaks_freq_range':    The range of frequencies to run
%                                   findpeaks on
%                                   default: [6, 30]
%
%           - 'plot_on':            Whether to plot the spectrum for
%                                   visulization. Note: will plot at every
%                                   time step.
%                                   default : false
%
%           - 'percent_num':        At which percentile to perform the
%                                   normalization at. Will take the
%                                   percentile at each frequency point.
%                                   default : 3
%
%           - 'in_db':              Whether to employ findpeaks on spectrum
%                                   at each time slice after converting to
%                                   dB scale.
%                                   default: false
%
%           - 'smooth_Hz':          Will complete a smoothing at each time
%                                   slice of the spectrum before finding a
%                                   peak in the spindle frequence
%                                   range. Enter the number of Hz.
%                                   default: 0
%
%           - 'local_norm_minutes': Whether to perform the normalization of
%                                   a spectrum basecd on the local spectral values
%                                   versus the default which is the
%                                   percentile calculated across the entire
%                                   artifact/wake-free sleep recording.
%                                   default: 0
%
%           - 'time_range':         Option to calculate only a portion of
%                                   the night.
%                                   default = [:] (full night)
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% ##### Outputs:
%       In case of multiple channels, outputs will have multiple columns representing
%       the multiple channel input.
%
%           - fproms:           The peak prominence values at each time
%                               point found in the designated frequency
%                               range.
%
%           - ffreq:            The frequency at which the peak was
%                               detected.
%
%           - fwidth:           The width of the peak that was detected in
%                               the spectrum. The width is in units Hz.
%
%           - nscube:           Normalized spectrogram in the specified
%                               findpeaks_freq_range.
%
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

%%
fptic = tic;

% Parse inputs and preparation
[ valid_time_inds, normalized_spectrogram, peak_freq_range, findpeaks_freq_range, plot_on, verbose, in_db, findpeaks_version ] = fpeak_inputparse(spect,stimes,sfreqs,varargin{:});

% compute the frequency range to run findpeaks on
freq_select = sfreqs>=findpeaks_freq_range(1) & sfreqs<=findpeaks_freq_range(2);
sfreqs_segment = sfreqs(freq_select);

% valid time indices for running findpeaks
time_select = find(valid_time_inds==1);

if strcmp(findpeaks_version, 'linear') % linear processing 
    % linearize valid segments of spectrogram into a 1D vector interleaved with NaN
    spectrogram = [nan(length(time_select),1), normalized_spectrogram(time_select, freq_select)]';
    [spect_rows, spect_cols] = size(spectrogram);
    
    % findpeaks - linearized version controlling for rounding errors
    [~, peak_freqs, freq_width, proms, freq_width_x] = findpeaks_extents_fpeaks(spectrogram(:), 1:spect_rows*spect_cols, spect_rows);
    
    % extract maximal prominence peak properties at valid time indices
    [ fpeak_proms_valid, fpeak_freqs_valid, fpeak_bandwidths_valid, fpeak_bandwidth_bounds_valid ]...
        = fpeak_extract_peak_linear(peak_freqs, freq_width, proms, freq_width_x, spect_rows, sfreqs_segment, peak_freq_range, time_select);

elseif strcmp(findpeaks_version, 'par') % enable parallel processing 
    % get valid segments of spectrogram
    spectrogram_segment = normalized_spectrogram(time_select, freq_select);
    
    % Store peak properties for each spectrum for valid time points
    fpeak_proms_valid = nan(length(time_select),1);
    fpeak_freqs_valid = nan(length(time_select),1);
    fpeak_bandwidths_valid = nan(length(time_select),1);
    fpeak_bandwidth_bounds_valid = nan(length(time_select),2);
    
    % Loop over all valid time slices and find peaks
    parfor tt = 1:length(time_select)
        
        spect_cur = spectrogram_segment(tt,:);
        
        % findpeaks on the spectrum in the specified frequency range
        [~, peak_freqs, freq_width, proms, freq_width_x] = findpeaks_extents_fpeaks(spect_cur, sfreqs_segment);
        if size(freq_width_x,1) < size(freq_width_x,2)
            freq_width_x = freq_width_x';
        end
        
        % Identify the peaks in the specified frequency range
        peaks_in_range = peak_freqs >= peak_freq_range(1) & peak_freqs <= peak_freq_range(2); %#ok<PFBNS>
        
        % Store parameters of these detected peaks
        max_prom = max(proms(peaks_in_range));
        if isempty(max_prom)
            fpeak_proms_valid(tt) = nan;
            fpeak_freqs_valid(tt) = nan;
            fpeak_bandwidths_valid(tt) = nan;
            fpeak_bandwidth_bounds_valid(tt,:) = nan;
        else
            fpeak_proms_valid(tt) = max_prom;
            loc = find(proms==max_prom);
            fpeak_freqs_valid(tt) = peak_freqs(loc(1)); %if more than one peaks have the same prominence, we pick the first peak from the left (lower frequency)
            fpeak_bandwidths_valid(tt) = freq_width(loc(1));
            fpeak_bandwidth_bounds_valid(tt,:) = freq_width_x(loc(1),:);
        end
        
        %         visualize all the peaks identified - for DEBUGS
        
        %                 This is best implemented when investigating a single spindle
        %                 and therefore, providing the program with an adjusted stimes,
        %                 sfreqs, spect for that spindle.
        %
        %                 To use the debugging feature, the parfor loop above must be
        %                 changed to a for loop.
        
        %                 figure
        %                 ax = figdesign(2,1);
        %                 colormap jet;
        %
        %                 axes(ax(1))
        %                 imagesc(stimes, sfreqs, pow2db(normalized_spectrogram')); %normalized_spectrogram)');
        %                 axis xy;
        %                 climscale;
        %                 hline(peak_freq_range(1));
        %                 hline(peak_freq_range(2));
        %                 vline(stimes(tt),1);
        %
        %                 axes(ax(2))
        %                 findpeaks(spect_cur, sfreqs, 'Annotate', 'extents');
        %                 hold on
        %                 vline(peak_freq_range,2,'r','--');
        % %                 set(findall(gca, 'Type', 'Line'),'LineWidth',2);
        % %                 set(gca, 'FontSize', 20)
        %                 axis tight ;
        
    end
    
else
    error('Unknown findpeaks version.')
end

% Allocate the processed results to output variables
%instantiate the outputs of this function
stimes_length = length(stimes);
fpeak_proms = nan(stimes_length,1);
fpeak_freqs = nan(stimes_length,1);
fpeak_bandwidths= nan(stimes_length,1);
fpeak_bandwidth_bounds = nan(stimes_length,2);

%allocate the processed result from store to output
fpeak_proms(time_select,1) = fpeak_proms_valid;
fpeak_freqs(time_select,1) = fpeak_freqs_valid;
fpeak_bandwidths(time_select,1) = fpeak_bandwidths_valid;
fpeak_bandwidth_bounds(time_select,:) = fpeak_bandwidth_bounds_valid;

%% plot the spectogram and extracted peak prominence
% as a function of time for specified time_range
if plot_on
    
    figure
    ax = figdesign(2,1);
    colormap jet;
    linkaxes(ax,'x');
    
    axes(ax(1))
    if in_db
        imagesc(stimes, sfreqs, pow2db(normalized_spectrogram'));
    else
        imagesc(stimes, sfreqs, normalized_spectrogram');
    end
    axis xy;
    climscale;
    hline(peak_freq_range(1));
    hline(peak_freq_range(2));
    
    axes(ax(2))
    plot(stimes, fpeak_proms);
    axis tight ;
    
end

%%
if verbose
    disp('Time taken in running find_frequency_peaks:')
    toc(fptic)
    disp(' ')
end
% Complete!

end

function [ valid_time_inds, normalized_spectrogram, peak_freq_range, findpeaks_freq_range, plot_on, verbose, in_db, findpeaks_version ] = fpeak_inputparse(spect,stimes,sfreqs,varargin)
%% Configure optional input arguments:
optionalInputs = {'valid_time_inds','peak_freq_range','findpeaks_freq_range','in_db','smooth_Hz','norm_method','norm_time_inds','percent_num','local_norm_minutes','plot_on','verbose','findpeaks_version'};

% Default values
optionalDefaults = {true(1, length(stimes)), [9,17], [max(6, sfreqs(1)),min(30, sfreqs(end))], false, 0, 'none', true(1, length(stimes)), 3, 0, false, false, 'linear'};

% varargin check
assert(~mod(length(varargin),2), 'varargin is not of even length. Please check!')
valid_varargin = contains(varargin(1:2:end), optionalInputs);
assert(all(valid_varargin), 'some varargin cannot be recognized. Did you make a typo?')

% Update optionalDefaults values according to varargin
for ii = 1:length(optionalInputs)
    FlagIndex = find(strcmpi(optionalInputs{ii}, varargin)==1);
    assert(length(FlagIndex) <= 1,'Only one %s value can be entered as an input.', optionalInputs{ii})
    if ~isempty(FlagIndex)
        optionalDefaults{ii} = varargin{FlagIndex+1};
    end
end

% Instantiate these optional input variables
valid_time_inds = optionalDefaults{1};
peak_freq_range = optionalDefaults{2};
findpeaks_freq_range = optionalDefaults{3};
in_db = optionalDefaults{4};
smooth_Hz = optionalDefaults{5};
norm_method = optionalDefaults{6};
norm_time_inds = optionalDefaults{7};
percent_num = optionalDefaults{8};
local_norm_minutes = optionalDefaults{9};
plot_on = optionalDefaults{10};
verbose = optionalDefaults{11};
findpeaks_version = optionalDefaults{12};

% sanity checks
assert(sfreqs(1) <= peak_freq_range(1) && sfreqs(end) >= peak_freq_range(2), 'peak detection range falls outside the spectrogram frequency range.')
findpeaks_freq_range(1) = max(sfreqs(1), findpeaks_freq_range(1));
findpeaks_freq_range(2) = min(sfreqs(end), findpeaks_freq_range(2));
assert(sfreqs(1) <= findpeaks_freq_range(1) && sfreqs(end) >= findpeaks_freq_range(2), 'findpeaks range falls outside the spectrogram frequency range.')
if peak_freq_range(1) < findpeaks_freq_range(1)
    findpeaks_freq_range(1) = max(sfreqs(1), peak_freq_range(1)-1);
    warning('Peak detection range is outside the findpeaks range, adjusted findpeaks lower bound with 1Hz margin. Please consider using a wider findpeaks range.')
end
if peak_freq_range(2) > findpeaks_freq_range(2)
    findpeaks_freq_range(2) = min(sfreqs(end), peak_freq_range(2)+1);
    warning('Peak detection range is outside the findpeaks range, adjusted findpeaks higher bound with 1Hz margin. Please consider using a wider findpeaks range.')
end
assert(length(valid_time_inds) == length(stimes), 'Time selection vector length is different from that of stimes.')

% Report out the parameters
if verbose
    disp(' ')
    disp('FIND_FREQUENCY_PEAKS PARAMETERS: ')
    disp(['findpeaks version: ', findpeaks_version])
    disp(['peak valid frequency range: ', num2str(peak_freq_range(1)), 'Hz - ', num2str(peak_freq_range(2)), 'Hz'])
    disp(['findpeaks frequency range: ', num2str(findpeaks_freq_range(1)), 'Hz - ', num2str(findpeaks_freq_range(2)), 'Hz'])
    disp(['in_db scale: ', num2str(in_db)])
    disp(['smooth(Hz): ', num2str(smooth_Hz)])
    disp(['normalization method: ', norm_method])
    if ~strcmp(norm_method, 'none')
        disp(['percentile for normalization: ', num2str(percent_num)])
        disp(['local normalization(minute): ', num2str(local_norm_minutes)])
    end
    disp(['plot_on: ', num2str(plot_on)])
    disp(['verbose: ', num2str(verbose)])
end

%% Preparation of inputs to findpeaks
%prepare for normalization of spectrum
if strcmp(norm_method, 'none')
    normalized_spectrogram = spect;
% elseif strcmp(norm_method, 'percentile')
%     % make sure percentile is non-zero
%     assert(percent_num > 0, 'Percentile normalization is used, but percentile is 0. Please use a higher percentile to normalize by.')
%     fullnight_percentiles = prctile(spect(norm_time_inds,:), percent_num);
%     if local_norm_minutes == 0
%         % make sure none of the values of the low percentile spectrum is tiny.
%         assert(sum(fullnight_percentiles<10^-4)==0, 'Must specify a higher percentile to normalize by. Have your data been checked for artifacts?');
%         normalized_spectrogram = spect ./ fullnight_percentiles;
%     elseif local_norm_minutes > 0 % this part is not fully supported yet!
%         %creates the matrix of percentile values to divide by
%         norm_interp_mat = local_normalization(stimes, sfreqs, spectrogam, 'windowsize', local_norm_minutes*2);
%         normalized_spectrogram = spect ./ norm_interp_mat';
%     else
%         error('Could not normalize spectrogram by percentile. Check the inputs.');
%     end
else
    error('norm_method variable is not a valid string. Please check the input')
end

% smooth the spectrum before findpeaks - not recommended, should control smoothing with multi-taper parameters.
if smooth_Hz > 0
    % Compute smoothing points in the frequency dimension of spectrum
    assert(length(unique(diff(sfreqs)))==1, 'frequency intervals of spectrogram are not unique.')
    smooth_samples = floor(smooth_Hz/unique(diff(sfreqs)));
    normalized_spectrogram = movmean(normalized_spectrogram, smooth_samples, 2);
end

% convert to dB scale for the spectrum before findpeaks
if in_db
    normalized_spectrogram = pow2db(normalized_spectrogram);
end

end

function [ fpeak_proms_valid, fpeak_freqs_valid, fpeak_bandwidths_valid, fpeak_bandwidth_bounds_valid ] = fpeak_extract_peak_linear(peak_freqs, freq_width, proms, freq_width_x, spect_rows, sfreqs_segment, peak_freq_range, time_select)
% convert central frequencies from 1D sample indices to rows in 2D spectrogram
mod_peak_freqs = mod(peak_freqs, spect_rows);
time_slice_num = (peak_freqs - mod_peak_freqs) / spect_rows + 1;
if unique(time_slice_num) ~= length(time_select)
    warning('For some spectra, no peak was found at all. Is the spectrum monotonically decreasing?')
end

% keep only peaks falling within the desired frequency range
peak_freq_select = find(sfreqs_segment >= peak_freq_range(1) & sfreqs_segment <= peak_freq_range(2));
valid_peaks_select = mod_peak_freqs >= (peak_freq_select(1) + 1) & mod_peak_freqs <= (peak_freq_select(end) + 1); % shifted by 1 due to padded NaN
time_slice_num = time_slice_num(1,valid_peaks_select);
peak_freqs = mod_peak_freqs(1,valid_peaks_select);
freq_width = freq_width(1,valid_peaks_select);
proms = proms(valid_peaks_select,1);
freq_width_x = freq_width_x(valid_peaks_select,:);

% set up the indices to get peaks from each spectrum
diff_time_slice_num = diff(time_slice_num);
jump_points = [1, find(diff_time_slice_num>0)+1];
cast_indices = [jump_points', [jump_points(2:end)-1, length(time_slice_num)]'];

% useful variables during extraction of peak properties
sfreqs_lookup = [-1, sfreqs_segment]; % added -1 due to padded NaN
bandwidth_converter = (sfreqs_segment(end) - sfreqs_segment(1)) / (spect_rows-2); % -2 due to padded NaN

% store peak properties for each spectrum for valid time points
time_select_length = length(time_select);
fpeak_proms_valid = nan(time_select_length,1);
fpeak_freqs_valid = nan(time_select_length,1);
fpeak_bandwidths_valid = nan(time_select_length,1);
fpeak_bandwidth_bounds_valid = nan(time_select_length,2);

% get properties of peak within each spectrum with maximal prominence value
for pp = 1:size(cast_indices,1)
    current_inds = cast_indices(pp,1):cast_indices(pp,2);
    fill_row_num = time_slice_num(current_inds(1));
    
    [~, k] = max(proms(current_inds,1));
    pick_ind = current_inds(k);
    
    fpeak_proms_valid(fill_row_num,1) = proms(pick_ind,1);
    fpeak_freqs_valid(fill_row_num,1) = sfreqs_lookup(peak_freqs(1,pick_ind));
    fpeak_bandwidths_valid(fill_row_num,1) = freq_width(1,pick_ind) * bandwidth_converter;
    fpeak_bandwidth_bounds_valid(fill_row_num,:) = (freq_width_x(pick_ind,:)-2) .* bandwidth_converter + sfreqs_segment(1);
end

%sanity check before outputting
assert(~any(fpeak_freqs_valid==-1), 'Some central frequency values are still -1.')

end