function [SOPhase, t_data]= computeSOPhase(data, Fs, SO_freqrange, filter)
% Computes slow-oscillation phase
%
% Inputs:
%       data: 1xN double - timeseries EEG data --required
%       Fs: numeric - sampling frequency of EEG (Hz) --required
%       SO_freqrange: 1x2 double - min and max frequencies (Hz) considered to be "slow oscillation".
%                     Default = [0.3, 1.5]
%       filter: digitalFilter - filter used to smooth EEG data before hilbert transform. Default
%               will use a precomputed filter if one exists for the Fs and SO_freqrange selected
%               and will compute a filter internally if not (this process will slow the runtime
%               and a warning will output).
%
% Outputs:
%       SOPhase: 1xN double - timeseries SO-phase data UNWRAPPED (radians)
%       t_data: 1xN double - times for each data point in SOPhase
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach,
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%       for Electroencephalographic Phenotyping and Biomarker Identification,
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%**********************************************************************

if nargin < 3 || isempty(SO_freqrange)
    SO_freqrange = [0.3, 1.5];
end

if nargin < 3 || isempty(filter)
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

filtdata = filtfilt(d,double(data));

data_analytic = hilbert(filtdata);
SOPhase = unwrap(angle(data_analytic)-pi);
t_data = (0:length(data)-1)/Fs;

end


