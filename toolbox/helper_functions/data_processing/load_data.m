function [data, Fs, stage_times, stage_vals] = load_data(varargin)

%% INPUT PARSER
p = inputParser;
% Required inputs
addRequired(p, 'edf_fpath', @(x) validateattributes(x, {'char','cell'},{}));
addRequired(p, 'scoring_fpath', @(x) validateattributes(x, {'char','cell'},{}));
addRequired(p, 'stage_col', @(x) validateattributes(x,{'double'},{'real','positive'}));
addRequired(p, 'time_col', @(x) validateattributes(x,{'double'},{'real','positive'}));
addRequired(p, 'channels',@(x)validateattributes(x,{'char','cell'},{}));
% Optional inputs for reading stages
addOptional(p, 'stage_vals_in', [], @(x) isempty(x) || iscell(x));
addOptional(p, 'header_lines', []);
addOptional(p, 'delimiter',',');
addOptional(p, 'start_time', NaN, @(x) ischar(x) || isstring(x) || isnan(x));
addOptional(p, 'epoch_dur', 30, @(x) isnumeric(x) && isscalar(x) && x>0);
addOptional(p, 'plot_on', false, @(x) islogical(x) && isscalar(x));
% Optional inputs for the batch function
addOptional(p, 'resample_freq', [], @(x) validateattributes(x,{'double'},{'real','positive'}));

parse(p,varargin{:});
input_arguments = struct2cell(p.Results); %#ok<NASGU>
input_flags = fieldnames(p.Results);
eval(['[', sprintf('%s ', input_flags{:}), '] = deal(input_arguments{:});']);

if ~iscell(channels) %#ok<NODEF>
    channels = {channels};
end

%% LOAD EDF
[~, signalHeader] = read_EDF(edf_fpath);
idx = ismember(channels,{signalHeader.signal_labels});
if ~all(idx)
    error(char(strcat('Invalid channels:',{' '},channels(~idx),' | Valid channels: ',{' '},sprintf('%s ',signalHeader.signal_labels))))
end

[header, signalHeader,data] = read_EDF(edf_fpath,'channels',channels,'forceMATLAB',true);
data = cell2mat(data);

Fs = [signalHeader.sampling_frequency];
Fs = Fs(idx);

% Test to see whether start time is valid
time_str = header.recording_starttime;
 % If start time is invalid, try converting periods to colons
% (Any other formatting error is the user's responsibility
inds = strfind(time_str,'.');
% Converting only the first two periods to colons to allow for 
% fractional seconds
if length(inds)>=2
    time_str(inds(1:2)) = ':';
end

try 
    datetime(time_str);
catch e
    if strcmp(e.identifier,'MATLAB:datetime:ParseErrs')
        error([header.recording_starttime,' is not a valid datetime format. Please replace with the following format: hh:mm:ss']);
    end
end
header.recording_starttime = time_str;
%% LOAD SCORING
if isnumeric(header_lines) & ~isempty(header_lines)
    staging = read_staging(scoring_fpath,time_col,stage_col,'stage_vals',stage_vals_in,'header_lines',header_lines,'start_time',header.recording_starttime,'delimiter',delimiter,'epoch_dur',epoch_dur,'plot_on',plot_on);
else
    %% TO-DO: CHECK THIS
    staging = read_staging(scoring_fpath,time_col,stage_col,'stage_vals',stage_vals_in,'start_time',header.recording_starttime,'delimiter',delimiter,'epoch_dur',epoch_dur,'plot_on',plot_on);
end
    
stage_times = staging.times;
stage_vals = staging.vals;

%% RESAMPLING (if requested)
if ~isempty(resample_freq) 
    data = smartresample(data,Fs,resample_freq);
end

end

