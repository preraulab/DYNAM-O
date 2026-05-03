function createUIFigureAndShell(app)
    %createUIFigureAndShell  Build the top-level figure, File menu,
    %   the three outer tabs (DYNAM-O Setup, Results Browser, Analysis),
    %   and the root grid that the Setup tab's content lives inside.
    % ---- Figure ----
    % Create UIFigure and hide until all components are created
    app.UIFigure = uifigure('Visible', 'off');
    % Get screen size
    screenSize = get(0, 'ScreenSize');  % [left bottom width height]

    % Compute centered position
    x = (screenSize(3) - app.WindowWidth) / 2;
    y = (screenSize(4) - app.WindowHeight) / 2;

    % Set figure position
    app.UIFigure.Position = [x, y, app.WindowWidth, app.WindowHeight];
    app.UIFigure.Name = 'DYNAM-O File Manager';
    app.UIFigure.AutoResizeChildren = 'off';   % grid handles it, not figure

    % Set the callback ON THE PANEL, not the figure
    app.UIFigure.SizeChangedFcn = @(src, event) app.enforceMinSize;

    % ---- File Menu ----
    app.FileMenu      = uimenu(app.UIFigure);
    app.FileMenu.Text = 'File';

    % Menu item: load a text file containing EDF paths (one per line)
    app.LoadEDFFileListMenu = uimenu(app.FileMenu);
    app.LoadEDFFileListMenu.MenuSelectedFcn = createCallbackFcn(app, @loadDataFileListCallback, true);
    app.LoadEDFFileListMenu.Text = 'Load EDF File List...';

    % Menu item: load a text file containing staging file paths (one per line)
    app.LoadStagingFileListMenu = uimenu(app.FileMenu);
    app.LoadStagingFileListMenu.MenuSelectedFcn = createCallbackFcn(app, @loadStagingListCallback, true);
    app.LoadStagingFileListMenu.Text = 'Load Staging File List...';

    % Menu item: toggle the floating Run Log Console window
    app.ShowRunLogConsoleMenu = uimenu(app.FileMenu);
    app.ShowRunLogConsoleMenu.MenuSelectedFcn = createCallbackFcn(app, @toggleRunLogConsole, true);
    app.ShowRunLogConsoleMenu.Text = 'Show Run Log Console';
    app.ShowRunLogConsoleMenu.Separator = 'on';

    % ---- Outer Tab Group ----
    % ---- Top-level grid fills the figure automatically ----
    rootGrid = uigridlayout(app.UIFigure, [1 1]);
    rootGrid.Padding  = [0 0 0 0];
    rootGrid.RowHeight   = {'1x'};
    rootGrid.ColumnWidth = {'1x'};

    % ---- Tab group lives inside the grid, NOT positioned manually ----
    app.ProjectTabGroup = uitabgroup(rootGrid); % parent = grid, not figure

    % ---- DYNAM-O Setup Tab ----
    app.DYNAMOSetupTab       = uitab(app.ProjectTabGroup);
    app.DYNAMOSetupTab.Title = 'DYNAM-O Batch Run';

    % ---- Results Browser Tab (created here so it sits second
    %      in the tab strip; populated below after Setup is built)
    app.ResultsBrowserTab       = uitab(app.ProjectTabGroup);
    app.ResultsBrowserTab.Title = 'Results Browser';

    % ---- Analysis Tab (third) — host for SO-Histograms and any
    %      future cross-channel visualisations.
    app.AnalysisTab       = uitab(app.ProjectTabGroup);
    app.AnalysisTab.Title = 'Analysis';

    % Root grid: 1 column × 3 rows (instructions | main content | bottom bar)
    app.FullDYNAMOSetupGrid             = uigridlayout(app.DYNAMOSetupTab);
    app.FullDYNAMOSetupGrid.ColumnWidth = {'1x'};
    app.FullDYNAMOSetupGrid.RowHeight   = {'20x', '3x'};
    app.FullDYNAMOSetupGrid.RowSpacing  = 0;
    app.FullDYNAMOSetupGrid.ColumnSpacing  = 0;
    app.FullDYNAMOSetupGrid.Padding  = 5;
end
