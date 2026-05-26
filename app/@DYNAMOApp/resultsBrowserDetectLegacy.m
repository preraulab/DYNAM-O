function tf = resultsBrowserDetectLegacy(app)
    % resultsBrowserDetectLegacy  True if the loaded results tree appears to
    % contain output files in the pre-app (legacy) format that the migrators
    % can convert: legacy aux (.h5/.mat with per-sample artifacts /
    % SOpower_retain_Fs), 64-bit SOPH/splinefit TIFFs, or old-schema stats
    % CSVs (subjectID / BoundingBox columns).
    %
    % Works off the in-memory ResultsBrowserCache_ (no extra directory walk —
    % important on SMB) and only opens a small SAMPLE of candidate files per
    % type, so detection is cheap. A positive result is enough to offer
    % conversion; the converter itself is idempotent and reports exact counts.
    %
    % See also: convert_dynamo_outputs_to_app, loadResultsBrowserTree.

    tf = false;
    cache = app.ResultsBrowserCache_;
    if isempty(cache) || ~isstruct(cache), return, end

    files = collect_files_(cache);
    if isempty(files), return, end

    sep = filesep;
    isAux  = @(p) contains(p, [sep 'auxiliary_data' sep]) && ...
                  (endsWith(lower(p), '.h5') || endsWith(lower(p), '.mat'));
    isTiff = @(p) (contains(p, [sep 'SOPHs' sep]) || contains(p, [sep 'spline_basis' sep])) && ...
                  endsWith(lower(p), '.tiff') && ~contains(p, [sep 'aggregates' sep]);
    isStat = @(p) contains(p, [sep 'TFpeaks' sep]) && ...
                  endsWith(lower(p), '.csv') && contains(p, 'stats_table');

    if sample_any_(files(cellfun(isAux,  files)), @aux_is_legacy_),  tf = true; return, end
    if sample_any_(files(cellfun(isTiff, files)), @tiff_is_legacy_), tf = true; return, end
    if sample_any_(files(cellfun(isStat, files)), @stats_is_legacy_), tf = true; return, end
end


function out = collect_files_(node)
    % Depth-first gather of every file path in the cache tree.
    out = {};
    if isfield(node, 'files') && ~isempty(node.files)
        out = {node.files.path};
    end
    if isfield(node, 'dirs')
        for ii = 1:numel(node.dirs)
            out = [out, collect_files_(node.dirs{ii})]; %#ok<AGROW>
        end
    end
end


function tf = sample_any_(paths, checkFn)
    % Apply checkFn to the first few paths; true if any is legacy. Each check
    % is guarded so an unreadable file can't abort detection.
    tf = false;
    K = min(numel(paths), 6);
    for ii = 1:K
        try
            if checkFn(paths{ii}), tf = true; return, end
        catch
        end
    end
end


function tf = aux_is_legacy_(p)
    tf = false;
    if endsWith(lower(p), '.h5')
        info = h5info(p);
        names = {info.Datasets.Name};
    else  % .mat
        S = load(p, 'auxiliary_data');
        if ~isfield(S, 'auxiliary_data'), return, end
        names = fieldnames(S.auxiliary_data);
    end
    hasNew = any(ismember({'artifact_spans','SOpower_t_start','SOpower_freqrange'}, names));
    hasOld = any(ismember({'artifacts','SOpower_retain_Fs'}, names));
    tf = hasOld && ~hasNew;
end


function tf = tiff_is_legacy_(p)
    info = imfinfo(p);
    tf = ~isempty(info) && isfield(info, 'BitsPerSample') && info(1).BitsPerSample == 64;
end


function tf = stats_is_legacy_(p)
    appHeader = ['PeakTime,PeakFrequency,Duration,Bandwidth,Height,Volume,' ...
        'SegmentNum,Area,Peakiness,bbox_tl_s,bbox_tl_Hz,bbox_width_s,' ...
        'bbox_height_Hz,PeakStage,SOpower,SOphase'];
    hdr = '';
    fid = fopen(p, 'r');
    if fid < 0, tf = false; return, end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    line = fgetl(fid);
    if ischar(line), hdr = strtrim(line); end
    tf = ~strcmp(hdr, appHeader) && ...
         (contains(hdr, 'subjectID') || contains(hdr, 'BoundingBox'));
end
