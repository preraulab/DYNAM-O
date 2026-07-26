function s = mode_peak_stats(stats_table, idx, props)
%MODE_PEAK_STATS  Per-mode summary of TF-peak properties.
%
%   s = mode_peak_stats(stats_table, idx, props)
%
%   Given the member-peak selection `idx` (logical or numeric indices, e.g.
%   from GET_MODE_PEAKS), returns a struct with the count of member peaks
%   and the mean of each requested property over them. SOphase uses a
%   circular mean; every other property uses the arithmetic mean over the
%   finite member values (NaN if none are finite).
%
%   props : cellstr of stats_table column names. Default is the full
%           tracked set:
%             {PeakFrequency, Duration, Bandwidth, Height, Volume, Area,
%              Peakiness, SOpower, SOphase}
%           (Height = peak power = amplitude.)
%
%   Output struct fields: `count` plus one field per requested property.
% =========================================================================
%                  DYNAM-O Toolbox  |  Prerau Laboratory
% =========================================================================
if nargin < 3 || isempty(props)
    props = {'PeakFrequency','Duration','Bandwidth','Height','Volume', ...
             'Area','Peakiness','SOpower','SOphase'};
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
        s.(name) = NaN;   % property not present in this stats table
        continue
    end
    v = stats_table.(name)(members);
    v = v(isfinite(v));
    if isempty(v)
        s.(name) = NaN;
    elseif strcmpi(name, 'SOphase')
        s.(name) = angle(mean(exp(1i .* v)));   % circular mean
    else
        s.(name) = mean(v);
    end
end
end
