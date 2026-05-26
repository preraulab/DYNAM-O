function writeSOPHsAggregate(app, partial, outDir, channelName, axis, label)
    % writeSOPHsAggregate  Write 3-D MAT and multi-page TIFF aggregates
    % for one SOPHs axis. Skips entirely if no contributors were found,
    % or if the user declines to overwrite an existing aggregate.
    hasMat  = isstruct(partial.mat_struct) && ...
              ~isempty(fieldnames(partial.mat_struct));
    hasTiff = ~isempty(partial.tiff_pages);
    if ~hasMat && ~hasTiff, return, end

    base = fullfile(outDir, [channelName '_aggregate_SOPHs_' axis]);
    if ~app.confirmAggregateOverwrite(base, {'.mat','.tiff'}, channelName, label)
        app.appendResultsBrowserLog(sprintf('  [%s] %s: kept existing (skipped)', channelName, label));
        return
    end
    if ~isfolder(outDir), mkdir(outDir); end

    if hasMat
        aggregate = partial.mat_struct; %#ok<NASGU>
        save([base '.mat'], 'aggregate', '-v7.3');
        fld = ['SO' axis '_mat'];
        app.appendResultsBrowserLog(sprintf('  [%s] wrote %s.mat (size %s)', ...
            channelName, [channelName '_aggregate_SOPHs_' axis], ...
            mat2str(size(partial.mat_struct.(fld)))));
    end
    if hasTiff
        tiffPath = [base '.tiff'];
        if isfile(tiffPath), delete(tiffPath); end
        t = Tiff(tiffPath, 'w');
        cleaner = onCleanup(@() close(t));
        % Build a JSON ImageDescription for the first page so
        % downstream readers can recover bins AND per-page subject
        % IDs directly from the TIFF (no sidecar required). The
        % subjectIDs array is keyed in TIFF page order so a reader
        % can map page index → subject ID without the .txt sidecar
        % or the runs index. Sidecar still written below for
        % external tools that don't parse JSON tags. Naming
        % convention: camelCase `subjectID` for one, `subjectIDs`
        % for many — matches the per-subject TIFF singular form.
        tiffDesc = '';
        fb = []; sb = [];
        if isfield(partial,'freq_bins'), fb = partial.freq_bins; end
        if isfield(partial,'so_bins'),   sb = partial.so_bins;   end
        idsRow = {};
        if ~isempty(partial.tiff_ids)
            idsRow = reshape(cellstr(partial.tiff_ids), 1, []);
        end
        if ~isempty(fb) || ~isempty(sb) || ~isempty(idsRow)
            metaStruct = struct();
            if ~isempty(fb),     metaStruct.freq_bins = fb(:).'; end
            if ~isempty(sb),     metaStruct.(['SO' axis '_bins']) = sb(:).'; end
            if ~isempty(idsRow), metaStruct.subjectIDs = idsRow; end
            tiffDesc = jsonencode(metaStruct);
        end
        for kk = 1:numel(partial.tiff_pages)
            page = partial.tiff_pages{kk};
            tagstruct.ImageLength      = size(page, 1);
            tagstruct.ImageWidth       = size(page, 2);
            tagstruct.Photometric      = Tiff.Photometric.MinIsBlack;
            tagstruct.BitsPerSample    = 64;
            tagstruct.SamplesPerPixel  = 1;
            tagstruct.SampleFormat     = Tiff.SampleFormat.IEEEFP;
            tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
            tagstruct.Compression      = Tiff.Compression.None;
            if kk == 1 && ~isempty(tiffDesc)
                tagstruct.ImageDescription = tiffDesc;
            elseif isfield(tagstruct,'ImageDescription')
                tagstruct = rmfield(tagstruct,'ImageDescription');
            end
            t.setTag(tagstruct);
            t.write(page);
            if kk < numel(partial.tiff_pages)
                t.writeDirectory();
            end
        end
        clear cleaner;

        sidecar = [base '_subjectIDs.txt'];
        ids = partial.tiff_ids;
        fid = fopen(sidecar, 'w');
        for kk = 1:numel(ids)
            fprintf(fid, '%s\n', ids{kk});
        end
        fclose(fid);
        app.appendResultsBrowserLog(sprintf('  [%s] wrote %s.tiff (%d pages)', ...
            channelName, [channelName '_aggregate_SOPHs_' axis], ...
            numel(partial.tiff_pages)));
    end

    % Bins CSV — one file per aggregate, two columns padded with NaN
    % to the longer length so plotting can label axes in Hz/dB/rad.
    freq_bins = []; so_bins = [];
    if isfield(partial, 'freq_bins'), freq_bins = partial.freq_bins; end
    if isfield(partial, 'so_bins'),   so_bins   = partial.so_bins;   end
    hasFreq = ~isempty(freq_bins);
    hasSO   = ~isempty(so_bins);
    if hasFreq || hasSO
        nF = numel(freq_bins); nS = numel(so_bins);
        nMax = max(nF, nS);
        fCol = nan(nMax, 1); if hasFreq, fCol(1:nF) = freq_bins(:); end
        sCol = nan(nMax, 1); if hasSO,   sCol(1:nS) = so_bins(:);   end
        soColName = ['SO' axis];
        Tbins = table(fCol, sCol, 'VariableNames', {'freq', soColName});
        writetable(Tbins, [base '_bins.csv']);
        app.appendResultsBrowserLog(sprintf('  [%s] wrote %s_bins.csv (%d rows)', ...
            channelName, [channelName '_aggregate_SOPHs_' axis], nMax));
    else
        app.appendResultsBrowserLog(sprintf('  [%s] no bins available — skipping bins.csv (re-run batch with .mat SOPHs to recover Hz/dB labels)', ...
            channelName));
    end
end
