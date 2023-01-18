function [SOpower_norm, SOpower_times, SOpower_stages, norm_method, ptile] = computeSOpower(EEG, Fs, varargin)
% COMPUTESOPOWER computes slow-oscillation power

%% Parse input
%Input Error handling
p = inputParser;

%Stage info
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'double', 'single'}, {'real'}));
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'numeric', 'vector'}, {'real'}));

%SOpower settings
addOptional(p, 'SO_freqrange', [0.3, 1.5], @(x) validateattributes(x, {'numeric', 'vector'}, {'real', 'finite', 'nonnan'}));
addOptional(p, 'SOpower_outlier_threshold', 3, @(x) validateattributes(x,{'numeric'}, {'scalar'}));
addOptional(p, 'norm_method', 'p2shift1234', @(x) validateattributes(x, {'char', 'numeric'},{}));
addOptional(p, 'retain_Fs', false, @(x) validateattributes(x,{'logical'},{}));
addOptional(p, 'tapers', [15 29], @(x) validateattributes(x,{'numeric', 'vector'}, {'numel',2}));
addOptional(p, 'window_params', [30 15], @(x) validateattributes(x,{'numeric', 'vector'}, {'numel',2}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'time_range', [], @(x) validateattributes(x, {'numeric', 'vector'},{'real','finite','nonnan'}));
addOptional(p, 'isexcluded', [], @(x) validateattributes(x, {'logical', 'vector'},{}));

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if isempty(EEG_times) %#ok<*NODEF>
    EEG_times = (0:length(EEG)-1)/Fs;
else
    assert(length(EEG_times) == size(EEG,2), 'EEG_times must be the same length as EEG');
end

if isempty(time_range)
    time_range = [min(EEG_times), max(EEG_times)];
else
    assert( (time_range(1) >= min(EEG_times)) & (time_range(2) <= max(EEG_times) ), 'lightsonoff_times cannot be outside of the time range described by "EEG_times"');
end

if isempty(isexcluded)
    isexcluded = false(size(EEG,2),1);
else
    assert(length(isexcluded) == size(EEG,2),'isexcluded must be the same length as EEG');
end

%% Compute SO power
% Replace artifact timepoints with NaNs
nanEEG = EEG;
nanEEG(isexcluded) = nan;

% Now compute SOpower
[SOpower, SOpower_times] = computeMTSpectPower(nanEEG, Fs, 'freq_range', SO_freqrange, 'tapers', tapers, 'window_params', window_params);
SOpower_times = SOpower_times + EEG_times(1); % adjust the time axis to EEG_times

% Compute SOpower stage
if ~isempty(stage_vals) && ~isempty(stage_times)
    SOpower_stages = interp1(stage_times, stage_vals, SOpower_times, 'previous');
else
    SOpower_stages = true;
end

% Exclude outlier SOpower that usually reflect isexcluded
SOpower(abs(nanzscore(SOpower)) >= SOpower_outlier_threshold) = nan;

% % Remove single time points sandwiched between nan values
% last_isnan = [0; isnan(SOpower(1:end-1))];
% next_isnan = [isnan(SOpower(2:end)); 0];
% SOpower(last_isnan & next_isnan) = nan;

%% Normalize SO power

%Handle shift inputs
if strcmpi(norm_method,'shift')
    shift_ptile = 2;
    shift_stages = 1:4;
elseif regexp(norm_method,'p[0-9]+shift*')
    shift_ptile = str2double(norm_method(2:strfind(norm_method,'shift')-1));
    shift_stages = unique((norm_method(strfind(norm_method,'shift')+5:end)) - '0');

    if isempty(shift_stages)
        shift_stages = 1:4;
    end

    norm_method = 'shift';
end

%Check shift
assert(shift_ptile >= 0 && shift_ptile <= 100, 'Shift percentile must be between 0 and 100');

% Note: right now the stage selection is only applied to the 'shift'
% method. If we were to use proportion, percentile, ALL stages will be
% used. Is this what we want? 

% Note: two other cases coded in SOpower_histogram_allstageTIB() is now
% removed:
%     case {'NREMshift', 'nrem', 'NREM'}
%         NREM_SOpow = SOpower_goodstages(ismember(stages_SOpower, [1,2]));
%         NREM_SOpow_mean_first5 = mean(NREM_SOpow(1:round(300/SOpow_times_step)), 'omitnan'); % mean of first 5 min of NREM
%         SOpower_norm = SOpower_goodstages - NREM_SOpow_mean_first5;
%         ptile = [];
% 
%     case {'N1', 'n1', 'N1shift', 'n1shift'}
%         N1_SOpow_mean = mean(SOpower_goodstages(stages_SOpower==3), 'omitnan');
%         SOpower_norm = SOpower_goodstages - N1_SOpow_mean;
%         ptile = [];

switch norm_method
    case {'proportion', 'normalized'}
        [proppower, ~] = computeMTSpectPower(nanEEG, Fs, 'freq_range', [freq_range(1), freq_range(2)]);
        SOpower_norm = db2pow(SOpower)./db2pow(proppower);
        ptile = [];

    case {'percentile', 'percent', '%', '%SOP'}
        low_val =  1;
        high_val =  99;
        ptile = prctile(SOpower(SOpower_times>=time_range(1) & SOpower_times<=time_range(2)), [low_val, high_val]);
        SOpower_norm = SOpower-ptile(1);
        SOpower_norm = SOpower_norm/(ptile(2) - ptile(1));  % Note: is this computation correct? 

    case {'shift'}
        if islogical(SOpower_stages) && SOpower_stages
            SOpower_stages_valid = true(size(SOpower_stages));
        else
            SOpower_stages_valid = ismember(SOpower_stages, shift_stages);
        end
        ptile = prctile(SOpower(SOpower_times>=time_range(1) & SOpower_times<=time_range(2) & SOpower_stages_valid), shift_ptile);
        SOpower_norm = SOpower-ptile(1);

    case {'absolute', 'none'}
        SOpower_norm = SOpower;
        ptile = [];

    otherwise
        error(['Normalization method "', norm_method, '" not recognized']);
end

% Make the output SOpower_norm a row vector 
SOpower_norm = SOpower_norm';

%% (Optional) Upsample to EEG sampling rate 
if retain_Fs
    SOpower_norm_notnan = SOpower_norm(~isnan(SOpower_norm));
    SOpower_norm = interp1([EEG_times(1), SOpower_times(~isnan(SOpower_norm)), EEG_times(end)],...
       [SOpower_norm_notnan(1), SOpower_norm_notnan, SOpower_norm_notnan(end)], EEG_times);
    SOpower_norm(isexcluded) = nan;
    SOpower_times = EEG_times;
    if ~isempty(stage_vals) && ~isempty(stage_times)
        SOpower_stages = interp1(stage_times, stage_vals, SOpower_times, 'previous');
    else
        SOpower_stages = true;
    end
end

end
