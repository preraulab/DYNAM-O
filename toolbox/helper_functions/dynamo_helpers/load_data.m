function [data, Fs, stage_times, stage_vals] = load_data(varargin)
%LOAD_DATA  Load EEG data and sleep staging from EDF and delimited text files
%
%   Usage:
%       [data, Fs, stage_times, stage_vals] = load_data(edf_fpath, scoring_fpath, stage_col, time_col, channels, ...)
%
%   Required Inputs:
%       edf_fpath:      char or cell - path(s) to EDF file(s) -- required
%       scoring_fpath:  char or cell - path(s) to scoring file(s) -- required
%       stage_col:      double - column number for sleep stage data (1-based) -- required
%       time_col:       double - column number for time data (1-based) -- required
%       channels:       char or cell - EEG channel label(s) to load -- required
%
%   Optional Inputs:
%       stage_vals_in:  cell - custom stage label mappings (default: [])
%       header_lines:   double - number of header lines in scoring file (default: [])
%       delimiter:      char - column delimiter (default: ',')
%       start_time:     char or string - recording start time (default: NaN)
%       epoch_dur:      double - epoch duration in seconds (default: 30)
%       plot_on:        logical - plot hypnogram (default: false)
%       resample_freq:  double - target resampling frequency in Hz (default: [])
%
%   Outputs:
%       data:           [N x C] double - EEG data matrix (samples x channels)
%       Fs:             double - sampling frequency in Hz
%       stage_times:    [1 x T] double - sleep stage onset times in seconds
%       stage_vals:     [1 x T] double - sleep stage values (0=Unk, 1=N3, 2=N2, 3=N1, 4=REM, 5=Wake)
%
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
%       Characterizing Individualized Neural Dynamics in Sleep EEG
% -------------------------------------------------------------------------
%
%   WEB        https://sleepeeg.org
%   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
%   GITHUB     https://github.com
%
%   ATTRIBUTION
%   If you use this toolbox, please cite:
%
%   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
%   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
%   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
%
%   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
%   Manoach, D. S., Stickgold, R., Prerau, M. J.
%   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
%   for Electroencephalographic Phenotyping and Biomarker Identification"
%   Sleep, 2022; zsac223. https://doi.org
%
% =========================================================================
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
% read_EDF derived-channels passthrough — when set, references are
% defined-name-bindings (e.g. 'LM = mean(A1,A2)') available to any
% expression in `channels`. read_EDF does the validation; we just
% forward the cell.
addParameter(p, 'References', {}, @iscell);

parse(p,varargin{:});
input_arguments = struct2cell(p.Results); %#ok<NASGU>
input_flags = fieldnames(p.Results);
eval(['[', sprintf('%s ', input_flags{:}), '] = deal(input_arguments{:});']);

if ~iscell(channels) %#ok<NODEF>
    channels = {channels};
end

%% LOAD EDF
[~, signalHeader] = read_EDF(edf_fpath);
all_labels       = {signalHeader.signal_labels};
all_labels_lower = lower(cellfun(@strtrim, all_labels, 'UniformOutput', false));

% When References are defined OR any channel uses derived-syntax
% markers, defer validation to read_EDF's own parser (which understands
% mean(...), aliasing, $LABEL$ escapes, etc.). The local A-B validator
% only handles plain labels and 'A-B' strings, so applying it here
% would reject perfectly valid expressions like 'C3 - mean(A1,A2)'.
has_derived = ~isempty(References);
if ~has_derived
    for k = 1:numel(channels)
        s = channels{k};
        if contains(s, 'mean(', 'IgnoreCase', true) || contains(s, '=') ...
                || contains(s, '+') || contains(s, '$')
            has_derived = true;
            break
        end
    end
end

if ~has_derived
    % Validate channels — accept plain labels and valid A-B rereferences.
    % Uses the same leftmost-dash split logic as read_EDF's parse_channel_plan.
    valid = false(size(channels));
    for k = 1:numel(channels)
        ch = strtrim(channels{k});
        if ismember(lower(ch), all_labels_lower)
            valid(k) = true;
        else
            dashes = strfind(ch, '-');
            for di = dashes
                chA = strtrim(ch(1:di-1));
                chB = strtrim(ch(di+1:end));
                if ~isempty(chA) && ~isempty(chB) && ...
                        ismember(lower(chA), all_labels_lower) && ...
                        ismember(lower(chB), all_labels_lower)
                    valid(k) = true;
                    break
                end
            end
        end
    end
    if ~all(valid)
        error(char(strcat('Invalid channels:',{' '},channels(~valid),' | Valid channels: ',{' '},sprintf('%s ',signalHeader.signal_labels))))
    end
end

[header, signalHeader, data] = read_EDF(edf_fpath, ...
    'Channels', channels, 'References', References);
data = cell2mat(data);

% signalHeader is now ordered to match channels (including any rereferenced
% virtual channels), so sampling frequencies are already in the right order.
Fs = [signalHeader.sampling_frequency];

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
if ~isempty(scoring_fpath)
    if isnumeric(header_lines) & ~isempty(header_lines)
        staging = read_staging(scoring_fpath,time_col,stage_col,'stage_vals',stage_vals_in,'header_lines',header_lines,'start_time',header.recording_starttime,'delimiter',delimiter,'epoch_dur',epoch_dur,'plot_on',plot_on);
    else
        %% TO-DO: CHECK THIS
        staging = read_staging(scoring_fpath,time_col,stage_col,'stage_vals',stage_vals_in,'start_time',header.recording_starttime,'delimiter',delimiter,'epoch_dur',epoch_dur,'plot_on',plot_on);
    end
    stage_times = staging.times;
    stage_vals = staging.vals;
else
    stage_times = [];
    stage_vals  = [];
end

%% RESAMPLING (if requested)
if ~isempty(resample_freq) 
    data = smartresample(data,Fs,resample_freq);
end

end

