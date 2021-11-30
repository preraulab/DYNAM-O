function [processed_ptiles, total_pow] = SW_percentiles_artifact_rejected(eeg_data, Fs, percentiles, num_std, units)
%SW_PERCENTILES_ARTIFACT_REJECTED Remove slow wave artifacts and compute
%percentiles on the slow wave power
%
%   Usage:
%   processed_ptiles = SW_percentiles_artifact_rejected(eeg_data, Fs, percentiles, num_std, units)
%
%   Input:
%   eegdata: 1x<samples> double vector of EEG time domain data
%   Fs: double, sampling frequency
%   percentiles: 1x2 double vector of percentiles to return (default: [1 99])
%   num_std: double, number of standard deviations for threshold (default: 3);
%   units: string, units for percentiles 'dB','sqrt','none' (default: 'dB'); 
%
%   Output:
%   processed_ptiles: 1x2 double vector of processed percentiles
%
%   Copyright 2018 Michael J. Prerau, Ph.D.
%
%   Last modified 09/13/2018
%********************************************************************

%Set defaults
if nargin<3
    percentiles=[1 99];
end

if nargin<4
    num_std=3;
end

if nargin<5
    units='db';
end


switch lower(units)
    case 'db'
        uval = 1;
    case {'absolute', 'none'}
        uval = 0;
    case 'sqrt'
        uval = 2;
    otherwise
        warning('Invalid unit selected. Use ''dB'', ''sqrt'', or ''none''');
end

%Transform the data to be positive and sqrt
% sqdata=sqrt(abs(quickbandpass(eeg_data,Fs,[30 min(55, floor(Fs/2)-1)])));
sqdata = sqrt(abs(eeg_data));

isartifact = isnan(sqdata) | isinf(sqdata);

[~,inds] = consecutive(sqdata==0,10);

for ii = 1:length(inds)
    isartifact(inds{ii}) = 1;
end

prethresh = nanmedian(sqdata)+10*std(sqdata);
isgiantartifact = sqdata>prethresh;
isartifact(isgiantartifact) = 1;

%Threshold
thresh = nanmedian(sqdata(~isartifact))+num_std*std(sqdata(~isartifact));

%Find the data above the threshold
isartifact = isartifact | sqdata>thresh;

%Compute the spectrogram with artifacts removed
data_noartifact = eeg_data;
data_noartifact(isartifact) = nan;

% spect = multitaper_spectrogram(data_noartifact,Fs,[.3 1.5],[15 29],[30 15],[],1,0);
spect = multitaper_spectrogram_mex(data_noartifact,Fs,[.3 1.5],[15 29],[30 15],[],'linear',[],false,false,true); % Changed to reflect new mt function

%Fix bad values
spect(isinf(spect)) = nan;

%Compute the total power
total_pow = real(sum(spect,2));
bad_inds = isnan(total_pow) | isinf(total_pow) | total_pow<=0;

if uval==1
 total_pow(~bad_inds) = pow2db(total_pow(~bad_inds));
elseif uval==2
 total_pow(~bad_inds) = sqrt(total_pow(~bad_inds));
end

%Return the processed percentiles
processed_ptiles = prctile(total_pow(~bad_inds),percentiles);
