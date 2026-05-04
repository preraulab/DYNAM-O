function ok = confirmAggregateOverwrite(app, baseStem, exts, channelName, label)
    % confirmAggregateOverwrite  Returns true if the caller may write
    % the aggregate file(s) — either none of them exist yet, or the
    % user said Overwrite (this one or all). Returns false (skip) if
    % the user said Skip (this one or all).
    %
    % A standing answer ("Overwrite All" / "Skip All") is honored for
    % the rest of the Aggregate run via app.AggregateOverwriteMode_.

    existing = {};
    for ii = 1:numel(exts)
        p = [baseStem exts{ii}];
        if isfile(p), existing{end+1} = p; end %#ok<AGROW>
    end
    if isempty(existing)
        ok = true; return
    end

    % Honor the standing "All" answer if one was given earlier.
    switch app.AggregateOverwriteMode_
        case 'all',  ok = true;  return
        case 'none', ok = false; return
    end

    shortNames = cell(size(existing));
    for ii = 1:numel(existing)
        [~, n, e] = fileparts(existing{ii});
        shortNames{ii} = [n e];
    end
    msg = sprintf(['Aggregate for %s in channel "%s" already exists:' ...
                   '\n\n%s\n\nOverwrite?'], ...
                  label, channelName, strjoin(shortNames, sprintf('\n')));
    try
        sel = uiconfirm(app.UIFigure, msg, 'Aggregate exists', ...
            'Options', {'Overwrite', 'Overwrite All', 'Skip', 'Skip All'}, ...
            'DefaultOption', 'Skip', ...
            'CancelOption',  'Skip', ...
            'Icon', 'question');
    catch
        % Fallback if uiconfirm isn't available: default to Skip.
        sel = 'Skip';
    end
    switch sel
        case 'Overwrite All'
            app.AggregateOverwriteMode_ = 'all';
            app.logResultsBrowser('  user chose: Overwrite All for this Aggregate run');
            ok = true;
        case 'Skip All'
            app.AggregateOverwriteMode_ = 'none';
            app.logResultsBrowser('  user chose: Skip All for this Aggregate run');
            ok = false;
        case 'Overwrite'
            ok = true;
        otherwise
            ok = false;
    end
end
