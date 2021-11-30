function [SWPhase, stimes]= compute_SWPhase( data, Fs, method, filter)
%COMPUTE_SWA Computes slow wave amplitude from the multitaper spectrogram
%   SWA = compute_SWA( data, Fs )
%
% Modified:
%   20210716 -- added filter param for precomputed filter (Tom P)

if nargin<3 || isempty(method)
    method = 'hilbert';
end

if nargin < 4 || isempty(filter)
    filter = [];
end

% [spect,stimes]=multitaper_spectrogram(data,Fs,[.5 1.5],[15 29],[30 15],[],1,0);
% [spect,stimes]=multitaper_spectrogram(data,Fs,[.5 1.5],[5 9],[5 1],[],1,0);

if isempty(filter)
    switch lower(method)
        case {'hilbert'}
            if Fs==500
                data_filt = SW_filt_500Hz(data);
            elseif Fs==100
                data_filt = SW_filtfilt_100Hz(data);
            else
                data_filt = quickbandpass(data,Fs,[.1 1.5],[],10000); % [0 2]);
            end
            data_analytic = hilbert(data_filt);
            SWPhase = unwrap(angle(data_analytic)-pi);
            stimes = (1:length(data))/Fs;
     %   case {'irasa'}
     %       addpath('/data/preraugp/projects/spindle_detection/code/irasa_code/IRASA');
   %          Frac = amri_sig_fractal(data,Fs,'detrend',1,'frange',frange);
    %         Frac.time = (0:step/Fs:step*(nwin-1)/srate)';
    %         SWPhase = sqrt(sum(spect,2));
        otherwise
            error('Invalid method');
    end
else
    switch lower(method)
        case {'hilbert'}
            data_filt = filtfilt(filter, data);

            data_analytic = hilbert(data_filt);
            SWPhase = unwrap(angle(data_analytic)-pi);
            stimes = (1:length(data))/Fs;

        otherwise
            error('Invalid method');
    end

end
end

