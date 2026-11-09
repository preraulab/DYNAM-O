function s = mode_peak_stats(stats_table, idx, varargin)
%MODE_PEAK_STATS  Count and summary of TF-peak properties over one mode's member peaks
%
%   Usage:
%       s = mode_peak_stats(stats_table, idx)
%       s = mode_peak_stats(stats_table, idx, props)
%       s = mode_peak_stats(stats_table, idx, props, 'Summary', 'mean')
%
%   Inputs:
%       stats_table : table - TF-peak stats table, one row per peak -- required
%       idx         : Nx1 logical or double - the mode's member peaks, as a
%                     logical mask over the rows of stats_table or as row
%                     numbers (e.g. one column of ASSIGN_MODE_PEAKS) -- required
%       props       : cell or string - stats_table column names to summarize
%                     (default: {'PeakFrequency','Duration','Bandwidth',
%                     'Height','Volume','Area','Peakiness','SOpower','SOphase'})
%
%   Name-Value Pairs:
%       'Summary' : char - statistic taken over the member peaks for every
%                   property but SOphase, 'median' or 'mean'
%                   (default: 'median')
%
%   Outputs:
%       s : struct - s.count is the number of member peaks, plus one field
%           per property in props holding its summary
%
%   Notes:
%       Each property is summarized over the members whose value is finite,
%       and is NaN when none is. A property missing from stats_table is NaN.
%       SOphase is always the circular mean, angle(mean(exp(1i*phase))),
%       whatever 'Summary' says, since neither a plain median nor a plain
%       mean is meaningful on a circle.
%
%       Why the median is the default: the per-peak size properties
%       (Height, Volume, Area, Duration) are heavy-tailed, so a mean is
%       dominated by a night's few giant tail events. On the NSS two-night
%       cohort this costs all of the night-to-night subject reliability
%       (mean PkVolume r about 0.0, median r about 0.8). MATLAB median
%       averages the two middle values on even counts, which matches the
%       Rust and Python implementations exactly.
%
%   Example:
%       members = assign_mode_peaks(params6, 'power', stats_table, 'argmax', background);
%       s = mode_peak_stats(stats_table, members(:, 1));
%       s.Duration   % median duration of mode 1's peaks
%
%   See also: annotateModesWithPeakStats, assign_mode_peaks, label_peaks_by_mode
%
%   ∿∿∿  Prerau Laboratory · sleepEEG.org  ∿∿∿

default_props = {'PeakFrequency','Duration','Bandwidth','Height','Volume', ...
                 'Area','Peakiness','SOpower','SOphase'};

p = inputParser;
addOptional(p, 'props', default_props, @(x) iscellstr(x) || isstring(x) || isempty(x));
addParameter(p, 'Summary', 'median', @(x) any(validatestring(x, {'median', 'mean'})));
parse(p, varargin{:});

props = p.Results.props;
if isempty(props)
    props = default_props;
end
props = cellstr(props);
summary = validatestring(p.Results.Summary, {'median', 'mean'});

if strcmp(summary, 'median')
    summarize = @median;
else
    summarize = @mean;
end

if islogical(idx)
    members = find(idx);
else
    members = idx(:);
end

s = struct();
s.count = numel(members);

for ii = 1:numel(props)
    name = props{ii};
    if ~ismember(name, stats_table.Properties.VariableNames)
        s.(name) = NaN;
        continue
    end
    values = stats_table.(name)(members);
    values = values(isfinite(values));
    if isempty(values)
        s.(name) = NaN;
    elseif strcmpi(name, 'SOphase')
        s.(name) = angle(mean(exp(1i .* values)));
    else
        s.(name) = summarize(values);
    end
end
end
