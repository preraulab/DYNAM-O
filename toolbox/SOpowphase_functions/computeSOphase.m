function [SOphase, SOphase_times, SOphase_stages, filtdata] = computeSOphase(varargin)
% COMPUTESOPHASE computes slow-oscillation phase

% To use a custom precomputed SO phase filter, use the 'SOphase_filter' argument
% custom_SOphase_filter = designfilt('bandpassfir', 'StopbandFrequency1', 0.1, 'PassbandFrequency1', 0.4, ...
%                        'PassbandFrequency2', 1.75, 'StopbandFrequency2', 2.05, 'StopbandAttenuation1', 60, ...
%                        'PassbandRipple', 1, 'StopbandAttenuation2', 60, 'SampleRate', 256);

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
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));

%SOphase computation params
SOphase_options = SOphase_opts(); % get the default parameters
addOptional(p, 'SO_freqrange', SOphase_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector','numel',2}));
addOptional(p, 'SOphase_filter', SOphase_options.SOphase_filter);

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

if isempty(isexcluded)
    isexcluded = false(length(EEG), 1);
else
    assert(length(isexcluded) == length(EEG),'isexcluded must be the same length as EEG');
end

%% Compute SO phase
if isempty(SOphase_filter)

    SOphase_filter_path = 'SOphase_filters.mat';
    filter_name = ['filter_', num2str(Fs), 'Hz_', strrep(num2str(SO_freqrange(1)),'.','dot'), '_', strrep(num2str(SO_freqrange(2)),'.','dot')];

    if ~isempty(who('-file', SOphase_filter_path, filter_name))

        load(SOphase_filter_path, filter_name)
        eval(['d = ', filter_name,';']); %#ok<EVLEQ>

    else

        warning(['SO phase filter not precomputed for Fs = ', num2str(Fs), ' and SO_freqrange = [', num2str(SO_freqrange(1)), ', ', num2str(SO_freqrange(2)), ...
            ']. Filter will be computed internally - this slows down the computation significantly. If running this function multiple times, it is recommended',...
            'to precompute the filter and pass it in as the "SOphase_filter" argument.']);

        d = designfilt('bandpassiir', ...       % Response type
            'StopbandFrequency1',SO_freqrange(1)-0.1, ...    % Frequency constraints
            'PassbandFrequency1',SO_freqrange(1), ...
            'PassbandFrequency2',SO_freqrange(2), ...
            'StopbandFrequency2',SO_freqrange(2)+0.1, ...
            'StopbandAttenuation1',60, ...   % Magnitude constraints
            'PassbandRipple',1, ...
            'StopbandAttenuation2',60, ...
            'DesignMethod','ellip', ...      % Design method
            'MatchExactly','passband', ...   % Design method options
            'SampleRate',Fs);
    end

else
    d = SOphase_filter;
end

filtdata = filtfilt(d, EEG);

data_analytic = hilbert(filtdata);
SOphase = unwrap(angle(data_analytic)); % phase of the real projection (cosine wave)
SOphase_times = EEG_times;

% Replace excluded times with nans
filtdata(isexcluded) = nan;
SOphase(isexcluded) = nan;

% Force the returned SOphase to be a row vector
if iscolumn(SOphase)
    SOphase = transpose(SOphase);
end

% Compute SOphase stage
if ~isempty(stage_times) && ~isempty(stage_vals)
    SOphase_stages = interp1(stage_times, stage_vals, SOphase_times, 'previous');
    SOphase_stages(isnan(SOphase_stages)) = 0; % a conservative choice to mark peaks outside scored stages as unknown
else
    SOphase_stages = true;
end

end
