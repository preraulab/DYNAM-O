function renderMatNodeValue(app, parent, val, label)
    % Type-aware render of a single .mat node into `parent`
    % (a uipanel or grid). `label` is the dotted variable path.

    if istable(val)
        ut = uitable(parent);
        ut.Units = 'normalized'; ut.Position = [0 0 1 1];
        ut.Data = val; ut.ColumnSortable = true;
        return
    end

    if ischar(val) || isstring(val)
        ta = app.makeFillTextArea(parent);
        ta.Value = cellstr(string(val));
        return
    end

    if isstruct(val) || iscell(val)
        ta = app.makeFillTextArea(parent);
        ta.Value = cellstr(splitlines(string(evalc('disp(val)'))));
        return
    end

    if islogical(val) || isnumeric(val)
        sz = size(val);
        if isscalar(val)
            uilabel(parent, 'Text', sprintf('%s = %s', label, num2str(val)), ...
                'Position',[10 10 600 30]);
            return
        end
        if numel(sz) == 2 && (sz(1) == 1 || sz(2) == 1)
            ax = uiaxes(parent, 'Units','normalized','Position',[0 0 1 1], ...
                'BackgroundColor','white');
            plot(ax, double(val(:)));
            grid(ax,'on');
            title(ax, sprintf('%s (%dx%d)', label, sz(1), sz(2)), ...
                'Interpreter','none');
            return
        end
        if numel(sz) == 2
            ax = uiaxes(parent, 'Units','normalized','Position',[0 0 1 1], ...
                'BackgroundColor','white');
            imagesc(ax, double(val));
            axis(ax,'xy'); colormap(ax,parula); colorbar(ax);
            title(ax, sprintf('%s (%dx%d)', label, sz(1), sz(2)), ...
                'Interpreter','none');
            return
        end
        if numel(sz) == 3
            nP = sz(3);
            g = uigridlayout(parent);
            g.ColumnWidth = {'1x'}; g.RowHeight = {'1x', 32};
            g.Padding = [4 4 4 4];
            ax = uiaxes(g, 'BackgroundColor','white');
            ax.Layout.Row = 1; ax.Layout.Column = 1;
            sliderRow             = uigridlayout(g);
            sliderRow.ColumnWidth = {'1x', '5x', '2x'};
            sliderRow.Padding     = [0 0 0 0];
            sliderRow.Layout.Row  = 2;
            uilabel(sliderRow, 'Tag','genPgLabel', 'Text','Page 1');
            sl = uislider(sliderRow, 'Limits',[1 max(1,nP)], 'Value',1, ...
                'MajorTicks',[],'MinorTicks',[]);
            sl.Layout.Column = 2;
            uilabel(sliderRow, 'Text', sprintf('of %d', nP), ...
                'HorizontalAlignment','right');
            app.drawMatVolumePage(ax, sliderRow, val, label, 1);
            sl.ValueChangedFcn = @(s,e) ...
                app.drawMatVolumePage(ax, sliderRow, val, label, round(s.Value));
            return
        end
    end

    % Fallback: text dump.
    ta = app.makeFillTextArea(parent);
    ta.Value = cellstr(splitlines(string(evalc('disp(val)'))));
end
