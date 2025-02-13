function [SOpower_norm, SOpower_times, SOpower_stages, norm_method, ptile] = computeSOpower(varargin)
% COMPUTESOPOWER: Computes slow oscillation power

%% Parse input
%Input Error handling
p = inputParser;

addRequired(p, 'EEG', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));

%Stage info
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nondecreasing','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double','single'}, {'real','finite','nonnegative','2d'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'time_range', [], @(x) isa(x,'numeric') && (isempty(x) || length(x) == 2));
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

%SOpower computation params
SOpower_options = SOpower_opts(); % get the default parameters
addOptional(p, 'SO_freqrange', SOpower_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'tapers', SOpower_options.SOpower_tapers, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'window_params', SOpower_options.SOpower_window_params, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'SOpower_outlier_threshold', SOpower_options.SOpower_outlier_threshold, @(x) validateattributes(x,{'numeric'},{'real','finite','scalar'}));
addOptional(p, 'norm_method', SOpower_options.SOpower_norm_method, @(x) validateattributes(x, {'char','string'}, {'nonempty','scalartext'}));
addOptional(p, 'retain_Fs', SOpower_options.SOpower_retain_Fs, @(x) validateattributes(x,{'logical'},{'scalar'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%Force EEG to be a column vector
if isrow(EEG)
    EEG = EEG(:);
end

if isempty(EEG_times) %#ok<*NODEF>
    EEG_times = (0:length(EEG)-1)/Fs;
else
    %Force EEG_times to be a row vector
    if iscolumn(EEG_times)
        EEG_times = transpose(EEG_times);
    end
    assert(length(EEG_times) == length(EEG), 'EEG_times must be the same length as EEG');
end

if isempty(time_range)
    time_range = [min(EEG_times), max(EEG_times)];
else
    assert( (time_range(1) >= min(EEG_times)) & (time_range(2) <= max(EEG_times)), 'time_range cannot be outside of the time range described by "EEG_times"');
end

if isempty(isexcluded)
    isexcluded = false(length(EEG), 1);
else
    assert(length(isexcluded) == length(EEG),'isexcluded must be the same length as EEG');
end

%% Compute SO power
% Replace artifact timepoints with NaNs
nanEEG = EEG;
nanEEG(isexcluded) = nan;

% Now compute SOpower
[SOpower, SOpower_times] = computeMTSpectPower(nanEEG, Fs, 'freq_range', SO_freqrange, 'tapers', tapers, 'window_params', window_params);
SOpower_times = SOpower_times + EEG_times(1); % adjust the time axis to EEG_times

% Compute SOpower stage
if ~isempty(stage_times) && ~isempty(stage_vals)
    SOpower_stages = interp1(stage_times, stage_vals, SOpower_times, 'previous');
    SOpower_stages(isnan(SOpower_stages)) = 0; % a conservative choice to mark peaks outside scored stages as unknown
else
    SOpower_stages = true;
end

% Exclude outlier SOpower that usually reflect isexcluded
SOpower(abs(nanzscore(SOpower)) >= SOpower_outlier_threshold) = nan;

%Check for all nan SOpower
if all(isnan(SOpower))
    warning('SOpower is all Nan')
    norm_method = nan;
    ptile = nan;
    return;
end

%% Normalize SO power
% Define the regular expression pattern for a valid shift string
pattern = '^p(0*[0-9]|[1-9][0-9]|100)shift[1-5]+$';

% Check if the input string matches the pattern
isValidShiftstr = ~isempty(regexp(norm_method, pattern, 'once'));

%Handle shift inputs
if strcmpi(norm_method, 'shift')
    shift_ptile = 2;
    shift_stages = 1:4;
elseif isValidShiftstr
    shift_ptile = str2double(norm_method(2:strfind(norm_method,'shift')-1));
    shift_stages = unique((norm_method(strfind(norm_method,'shift')+5:end)) - '0');

    if isempty(shift_stages)
        shift_stages = 1:4;
    end

    norm_method = 'shift';

    %Check shift
    assert(shift_ptile >= 0 && shift_ptile <= 100, 'Shift percentile must be between 0 and 100');
end

switch norm_method
    % To do: right now the stage selection is only applied to the 'shift'
    % method. If we were to use proportion, percentile, ALL stages will be
    % used. Is this what we want?
    case {'proportion', 'normalized'}
        [proppower, ~] = computeMTSpectPower(nanEEG, Fs, 'freq_range', [0.3, 40], 'tapers', tapers, 'window_params', window_params);
        SOpower_norm = db2pow(SOpower)./db2pow(proppower);
        ptile = [];

    case {'percentile', 'percent', '%', '%SOP'}
        low_val =  1;
        high_val =  99;
        ptile = prctile(SOpower(SOpower_times>=time_range(1) & SOpower_times<=time_range(2)), [low_val, high_val]);
        SOpower_norm = SOpower - ptile(1);
        SOpower_norm = SOpower_norm/(ptile(2) - ptile(1));  % Normalize between 1 and 0

    case {'shift'}
        %Check for valid shift stages
        SOpower_stages_valid = ismember(SOpower_stages, shift_stages);
        assert(any(SOpower_stages_valid), ['No valid stages found for shift normalization. {' num2str(shift_stages) '} are not valid members of {' num2str(unique(SOpower_stages)) '}']);

        ptile = prctile(SOpower(SOpower_times>=time_range(1) & SOpower_times<=time_range(2) & SOpower_stages_valid), shift_ptile);
        SOpower_norm = SOpower-ptile(1);

    case {'absolute', 'none'}
        SOpower_norm = SOpower;
        ptile = [];

    otherwise
        error(['Normalization method "', norm_method, '" not recognized']);
end

%% (Optional) Upsample to EEG sampling rate
if retain_Fs
    SOpower_norm_notnan = SOpower_norm(~isnan(SOpower_norm));
    SOpower_norm = interp1([EEG_times(1), SOpower_times(~isnan(SOpower_norm)), EEG_times(end)],...
        [SOpower_norm_notnan(1), SOpower_norm_notnan, SOpower_norm_notnan(end)], EEG_times);
    SOpower_norm(isexcluded) = nan;
    SOpower_times = EEG_times;
    if ~isempty(stage_times) && ~isempty(stage_vals)
        SOpower_stages = interp1(stage_times, stage_vals, SOpower_times, 'previous');
    else
        SOpower_stages = true;
    end
end

end


function [SO_power, stimes, sfreqs] = computeMTSpectPower(varargin)
% COMPUTEMTSPECTPOWER computes the slow oscillation power of timeseries data
% Usage:
%   [SO_power, stimes, sfreqs] = computeMTSpectPower(data, Fs, freq_range, tapers, window_params, smoothing_method, smoothing_param, interp_times, verbose)
%
%%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

%% Parse input
%Input Error handling
p = inputParser;

addRequired(p, 'data', @(x) validateattributes(x, {'numeric'}, {'real','vector'}));
addRequired(p, 'Fs', @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','scalar'}));

SOPH_options = SOpowerphasehist_opts(); % get the default parameters
addOptional(p, 'freq_range', SOPH_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'tapers', SOPH_options.SOpower_tapers, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'window_params', SOPH_options.SOpower_window_params, @(x) validateattributes(x, {'numeric'}, {'real','finite','positive','vector','numel',2}));
addOptional(p, 'smoothing_method', 'none', @(x) any(validatestring(x, {'none', 'movmean', 'movmedian', 'gaussian', 'lowess', 'loess', 'rlowess', 'rloess', 'sgolay'})));
addOptional(p, 'smoothing_param', 60*5, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','integer','scalar'}));
addOptional(p, 'interp_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','2d'}));
addOptional(p, 'verbose', false, @(x) validateattributes(x,{'logical'},{'scalar'}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

%Automatically add parser results to the workspace
eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

%Force data to be a column vector
if isrow(data)
    data = data(:);
end

%% Compute SO-power
%Compute power using the MTS (data, Fs, frequency_range, taper_params, window_params, min_NFFT, detrend_opt, weighting, plot_on, verbose)

[SO_spect, stimes, sfreqs] = multitaper_spectrogram_mex(data, Fs, freq_range, tapers, window_params, [], 'linear', [], false, verbose);

%Compute dt
dt = stimes(2) - stimes(1);
df = sfreqs(2) - sfreqs(1);

%Takes the total power and converts to dB
SO_power = nanpow2db(sum(SO_spect,1)*df); % this is now a row vector for the interp1

%% Smooth data
if ~strcmpi(smoothing_method, 'none') && ~isempty(smoothing_param) && smoothing_param>0

    if verbose
        disp(['Smoothing using ' smoothing_method ' with parameter ' num2str(smoothing_param)]);
    end

    %Get bad indices
    bad_inds = ~isfinite(SO_power);

    %Interpolate big gaps in data
    t = 1:length(SO_power); % this is a row vector
    data_fixed = interp1([0, t(~bad_inds), length(SO_power)+1], [0, SO_power(~bad_inds), 0], t); % this is also a row vector

    smooth_samples = smoothing_param/dt; %Time in samples

    SO_power = smoothdata(data_fixed, smoothing_method, smooth_samples, 'omitnan');

    %Return the bad values
    SO_power(bad_inds) = nan; % SO_power is a row vector in output
end

%% Interpolate data
if ~isempty(interp_times)
    SO_power = interp1(stimes, SO_power, interp_times);
    if iscolumn(SO_power)
        SO_power = transpose(SO_power); % ensure SO_power is still a row vector in output
    end
end

end
