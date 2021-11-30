function [SOPhase, stimes]= compute_SOPhase(data, Fs, SO_freqrange, filter)
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
%       stimes: 1xN double - times for each data point in SOPhase
%
%%%************************************************************************************%%%

if nargin < 3 || isempty(SO_freqrange)
    SO_freqrange = [0.3, 1.5];
end

if nargin < 3 || isempty(filter)
    filter = [];
end


if isempty(filter)
    
    SOphase_filter_path = '../SOphase_filters/SOphase_filters.mat';
    filter_name = ['filter_', num2str(Fs), 'Hz_', strrep(num2str(SO_freqrange(1)),'.','dot'), '_', strrep(num2str(SO_freqrange(2)),'.','dot')];
    
    if ~isempty(who('-file', SOphase_filter_path, filter_name))
        
        load(SOphase_filter_path, filter_name)
        eval(['d = ', filter_name,';']);
        
    else
        
        warning(['SO phase filter not precomputed for Fs = ', num2str(Fs), ' and SO_freqrange = [', num2str(SO_freqrange(1)), ', ', num2str(SO_freqrange(2)), ...
                 ']. Filter will be computed internally - this slows down the computation significantly. If running this function multiple times, it is recommended',...
                 'to precompute the filter and pass it in as the "SOphase_filter" argument.']);
                 
        d = designfilt('bandpassfir', 'StopbandFrequency1', max(0.1, SO_freqrange(1)-0.3), 'PassbandFrequency1', SO_freqrange(1), ...
                       'PassbandFrequency2', SO_freqrange(2), 'StopbandFrequency2', SO_freqrange(2)+0.3, 'StopbandAttenuation1', 60, ...
                       'PassbandRipple', 1, 'StopbandAttenuation2', 60, 'SampleRate', Fs);
    end
    
else
    d = filter;
end
               
filtdata = filtfilt(d,data);

data_analytic = hilbert(filtdata);
SOPhase = unwrap(angle(data_analytic)-pi);
stimes = (1:length(data))/Fs;

end


