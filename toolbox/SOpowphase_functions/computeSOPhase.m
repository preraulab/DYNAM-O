function [SOphase, SOphase_times, SOphase_stages] = computeSOphase(EEG, Fs, isexcluded, EEG_times, filter, SO_freqrange, stage_vals, stage_times)
% COMPUTESOPHASE computes slow-oscillation phase
if ~exist('SO_freqrange', 'var') || isempty(SO_freqrange)
    SO_freqrange = [0.3, 1.5];
end

if ~exist('filter', 'var') || isempty(filter)
    filter = [];
end

if isempty(filter)

    SOphase_filter_path = 'SOphase_filters.mat';
    filter_name = ['filter_', num2str(Fs), 'Hz_', strrep(num2str(SO_freqrange(1)),'.','dot'), '_', strrep(num2str(SO_freqrange(2)),'.','dot')];

    if ~isempty(who('-file', SOphase_filter_path, filter_name))

        load(SOphase_filter_path, filter_name)
        eval(['d = ', filter_name,';']);

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
    d = filter;
end

filtdata = filtfilt(d,double(EEG));

data_analytic = hilbert(filtdata);
SOphase = unwrap(angle(data_analytic)-pi);
SOphase_times = (0:length(EEG)-1)/Fs;

% Replace excluded times with nans
SOphase(isexcluded) = nan;

% Adjust the time axis to EEG_times
SOphase_times = SOphase_times + EEG_times(1); % adjust the time axis to EEG_times

% Compute SOphase stage
if ~isempty(stage_vals) && ~isempty(stage_times)
    SOphase_stages = interp1(stage_times, stage_vals, SOphase_times, 'previous');
else
    SOphase_stages = true;
end

end
