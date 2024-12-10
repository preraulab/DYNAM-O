function [SOphase, SOphase_times, SOphase_stages, filtdata] = computeSOphase(EEG, Fs, varargin)
% COMPUTESOPHASE computes slow-oscillation phase

%% Parse input
%Input Error handling
p = inputParser;

%Stage info
addOptional(p, 'stage_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','2d'}));
addOptional(p, 'stage_vals', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','2d'}));

%EEG time settings
addOptional(p, 'EEG_times', [], @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','2d'}));
addOptional(p, 'isexcluded', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','nonnan','2d'}));

%SOphase settings
SOPH_options = SOpowerphasehist_opts(); % get the default parameters
addOptional(p, 'SO_freqrange', SOPH_options.SO_freqrange, @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnan','nonnegative','vector','numel',2}));
addOptional(p, 'SOphase_filter', SOPH_options.SOphase_filter);

parse(p,varargin{:});
parser_results = struct2cell(p.Results); %#ok<NASGU>
field_names = fieldnames(p.Results);

eval(['[', sprintf('%s ', field_names{:}), '] = deal(parser_results{:});']);

if isempty(EEG_times) %#ok<*NODEF>
    EEG_times = (0:length(EEG)-1)/Fs;
else
    assert(length(EEG_times) == size(EEG,2), 'EEG_times must be the same length as EEG');
end

if isempty(isexcluded)
    isexcluded = false(size(EEG,2),1);
else
    assert(length(isexcluded) == size(EEG,2),'isexcluded must be the same length as EEG');
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

filtdata = filtfilt(d,double(EEG));

data_analytic = hilbert(filtdata);
SOphase = unwrap(angle(data_analytic));  % phase of the real projection (cosine wave)
SOphase_times = EEG_times;

% Replace excluded times with nans
filtdata(isexcluded) = nan;
SOphase(isexcluded) = nan;

% Compute SOphase stage
if ~isempty(stage_times) && ~isempty(stage_vals)
    SOphase_stages = interp1(stage_times, stage_vals, SOphase_times, 'previous');
else
    SOphase_stages = true;
end

end
