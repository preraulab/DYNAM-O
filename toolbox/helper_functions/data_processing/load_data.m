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

%% LOAD EDF
[header, signalHeader, signalCell] = read_EDF(edf_fpath);

% Select specific channels
labels = {signalHeader.signal_labels};
if iscell(channels)
    chan_inds = zeros(1,length(channels));
    for ii = 1:length(channels)
        chan_inds(ii) = find(strcmpi(labels,channels{ii}));
        if isempty(chan_inds(ii))
            error(char(strcat(channels{ii},' is not a valid channel. Valid channels:',{' '},sprintf('%s ',labels{:}))))
            % data = ['Channel ',channels{ii},' does not exist.'];
            % Fs = [];
            % stage_times = [];
            % stage_vals = [];
            % return
        end
    end
else
    chan_inds = find(strcmpi(labels,channels));
    if isempty(chan_inds)
        error(char(strcat(channels,' is not a valid channel. Valid channels:',{' '},sprintf('%s ',labels{:}))))
        % data = ['Channel ',channels,' does not exist.'];
        % Fs = [];
        % stage_times = [];
        % stage_vals = [];
        % return
    end
    labels = labels(chan_inds);
end

data = cell2mat(signalCell(chan_inds));

if isfield(header,'samplingfrequency')
    Fs = header.samplingfrequency(chan_inds);
else
    Fs_arr = [signalHeader.sampling_frequency];
    Fs = Fs_arr(chan_inds(1));
end


%% LOAD SCORING
if isnumeric(header_lines)
    [staging] = read_staging(scoring_fpath,time_col,stage_col,'stage_vals',stage_vals_in,'header_lines',header_lines,'start_time',start_time,'delimiter',delimiter,'epoch_dur',epoch_dur,'plot_on',plot_on);
else
    [staging] = read_staging(scoring_fpath,time_col,stage_col,'stage_vals',stage_vals_in,'start_time',start_time,'delimiter',delimiter,'epoch_dur',epoch_dur,'plot_on',plot_on);
end
    
stage_times = staging.times;
stage_vals = staging.vals;

%% RESAMPLING (if requested)
if ~isempty(resample_freq) 
    data = smartresample(data,Fs,resample_freq);
end

end

