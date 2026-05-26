function renderResultsBrowserPreviewH5(app, p)
    % renderResultsBrowserPreviewH5  Preview a generic HDF5 file
    % (DYNAM-O writes auxiliary_data.h5 via h5create+h5write per
    % field — every aux scalar / vector / string lands as a
    % top-level dataset). Renders a two-column table: dataset name
    % on the left, an inline value (scalars, short strings) or a
    % shape/type summary (for arrays) on the right.

    delete(app.ResultsBrowserPreviewBody.Children);
    try
        info = h5info(p);
    catch ME
        app.renderResultsBrowserPreviewMessage( ...
            sprintf('h5info failed:\n%s', ME.message));
        return
    end
    if isempty(info.Datasets)
        app.renderResultsBrowserPreviewMessage('Empty .h5 file (no top-level datasets).');
        return
    end

    nDs = numel(info.Datasets);
    rows = cell(nDs, 2);
    for ii = 1:nDs
        ds = info.Datasets(ii);
        rows{ii, 1} = ds.Name;
        rows{ii, 2} = format_summary_(p, ds);
    end

    g = uigridlayout(app.ResultsBrowserPreviewBody);
    g.ColumnWidth = {'1x'};
    g.RowHeight   = {'1x'};
    g.Padding     = [4 4 4 4];

    t = uitable(g);
    t.Layout.Row = 1; t.Layout.Column = 1;
    t.ColumnName = {'Dataset', 'Value / Size'};
    t.ColumnWidth = {220, '1x'};
    t.Data = rows;
    t.RowName = [];
end


function s = format_summary_(p, ds)
    % Inline short scalars and strings; otherwise show
    % "<class> <size>" without loading the full payload.
    sz = ds.Dataspace.Size;
    if isempty(sz), sz = [1 1]; end
    nElem = prod(max(sz, 1));
    cls = ds.Datatype.Class;

    isScalarLike = nElem == 1;
    isShortVec   = nElem > 1 && nElem <= 8;

    try
        if strcmpi(cls, 'H5T_STRING') && isScalarLike
            v = h5read(p, ['/' ds.Name]);
            if isstring(v) || iscell(v), v = char(string(v)); end
            s = char(v);
            return
        end
        if isScalarLike
            v = h5read(p, ['/' ds.Name]);
            s = format_scalar_(v);
            return
        end
        if isShortVec
            v = h5read(p, ['/' ds.Name]);
            s = ['[' strjoin(arrayfun(@format_scalar_, v(:).', 'UniformOutput', false), ', ') ']'];
            return
        end
    catch
        % fall through to size-only summary
    end
    s = sprintf('%s  size=%s', class_label_(cls), mat2str(sz));
end


function s = format_scalar_(v)
    if islogical(v)
        s = sprintf('%d', double(v));
    elseif isnumeric(v)
        if v == fix(v) && abs(v) < 1e9
            s = sprintf('%d', v);
        else
            s = sprintf('%.6g', v);
        end
    elseif isstring(v) || ischar(v)
        s = char(string(v));
    else
        s = sprintf('<%s>', class(v));
    end
end


function lbl = class_label_(cls)
    % Friendlier names than the H5T_* enum values.
    switch upper(string(cls))
        case "H5T_STRING",  lbl = 'string';
        case "H5T_INTEGER", lbl = 'int';
        case "H5T_FLOAT",   lbl = 'double';
        otherwise,          lbl = char(string(cls));
    end
end
