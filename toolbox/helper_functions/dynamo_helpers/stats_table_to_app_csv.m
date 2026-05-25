function T = stats_table_to_app_csv(T)
%STATS_TABLE_TO_APP_CSV  Reshape a stats_table into the app's 16-column CSV schema.
%
%   Usage:
%       T = stats_table_to_app_csv(T)
%
%   Produces the DYNAM-O desktop app's strict stats CSV layout:
%       PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,SegmentNum,
%       Area,Peakiness,bbox_tl_s,bbox_tl_Hz,bbox_width_s,bbox_height_Hz,
%       PeakStage,SOpower,SOphase
%   by dropping any subjectID column (subject attribution is recovered from
%   the filename on read) and decomposing the Nx4 BoundingBox matrix column
%   into bbox_tl_s / bbox_tl_Hz / bbox_width_s / bbox_height_Hz.
%
%   When the table lacks some schema columns (non-standard feature set), the
%   present schema columns are written first in canonical order followed by
%   any extras, with a warning — MATLAB round-trips it but the app reader,
%   which validates the header strictly, will not accept it.
%
%   See also: writeStatsTableFormats, convert_stats_csv_to_app, loadStatsTable.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

if ~istable(T), return, end

vn = T.Properties.VariableNames;
sidHit = strcmpi(vn, 'subjectID');
if any(sidHit)
    T = removevars(T, vn(sidHit));
    vn = T.Properties.VariableNames;
end

% BoundingBox is an Nx4 matrix column [tl_s, tl_Hz, width_s, height_Hz].
bbHit = strcmpi(vn, 'BoundingBox');
if any(bbHit)
    bbName = vn{find(bbHit, 1)};
    BB = T.(bbName);
    if size(BB, 2) >= 4
        T.bbox_tl_s      = BB(:, 1);
        T.bbox_tl_Hz     = BB(:, 2);
        T.bbox_width_s   = BB(:, 3);
        T.bbox_height_Hz = BB(:, 4);
    end
    T = removevars(T, bbName);
end

want = {'PeakTime','PeakFrequency','Duration','Bandwidth','Height','Volume', ...
        'SegmentNum','Area','Peakiness','bbox_tl_s','bbox_tl_Hz','bbox_width_s', ...
        'bbox_height_Hz','PeakStage','SOpower','SOphase'};
vn = T.Properties.VariableNames;
if all(ismember(want, vn))
    T = T(:, want);
else
    missing = want(~ismember(want, vn));
    warning('stats_table_to_app_csv:schema', ...
        'stats CSV missing app-schema column(s): %s; writing available columns.', ...
        strjoin(missing, ', '));
    present = want(ismember(want, vn));
    extras  = setdiff(vn, present, 'stable');
    T = T(:, [present, extras]);
end
end
