classdef SmoothProgressBar < matlab.ui.componentcontainer.ComponentContainer
    % SmoothProgressBar - Smooth animated horizontal progress bar for MATLAB apps
    %
    %   This class provides a continuous-time progress bar for uifigure-based
    %   applications. The bar advances smoothly between iteration updates using a
    %   generalized sigmoid interpolation. It supports a color gradient, optional
    %   percentage display, time remaining, and x-axis tick marks.
    %
    % USAGE:
    %   pb = SmoothProgressBar(parent)
    %   pb = SmoothProgressBar(parent, N)
    %
    % NOTE:
    %   This ComponentContainer version is fully compatible with uigridlayout
    %   and App Designer. Layout is controlled via pb.Layout.Row / Column.
    %
    % INPUTS:
    %   parent        - UI container (uigridlayout, uifigure, uipanel)
    %   N             - Total number of iterations or work units (positive scalar)
    %
    % PUBLIC PROPERTIES:
    %   Parent             - Parent UI container (managed by ComponentContainer)
    %   Axes               - UIAxes used for rendering
    %   Bar                - Rectangle object representing filled portion
    %   N                  - Total iterations
    %   Timer              - Timer object for smooth updates
    %   Colormap           - Name of colormap
    %   ShowTimeRemaining  - Toggle time remaining display
    %   ShowPercentage     - Toggle percentage display
    %   BarHeight          - Relative bar height (0–1)
    %   FontSize           - Title font size
    %   FontColor          - Title font color
    %   TimerPeriod        - Timer update period in seconds (default: 0.05)
    %
    % METHODS:
    %   start()            - Start or restart the timer
    %   updateIteration(k) - Notify the bar that iteration k has completed
    %   complete()         - Force the bar to complete immediately
    %   refresh()          - Reset the progress bar to zero
    %
    % EXAMPLE:
    %   fig = uifigure('Position',[100 100 600 250]);
    %   gl = uigridlayout(fig,[3 1]);
    %
    %   pb = SmoothProgressBar(gl, 10);
    %   pb.Layout.Row = 2;
    %
    %   pb.ShowPercentage = true;
    %   pb.ShowTimeRemaining = true;
    %
    %   pb.start();
    %   for k = 1:10
    %       pause(2 + rand);
    %       pb.updateIteration(k);
    %   end
    %
    % =========================================================================
    %                  DYNAM-O Toolbox  |  Prerau Laboratory
    %       Characterizing Individualized Neural Dynamics in Sleep EEG
    % -------------------------------------------------------------------------
    %
    %   WEB        https://sleepeeg.org
    %   TUTORIALS  https://prerau.bwh.harvard.edu/dynam-o/
    %   GITHUB     https://github.com
    %
    %   ATTRIBUTION
    %   If you use this toolbox, please cite:
    %
    %   He, M., Saremsky, S., Noamany, H., Chen, S., Prerau, M.J.
    %   "DYNAM-O Toolbox: Characterizing Individualized Neural Dynamics
    %   in Sleep EEG", bioRxiv, 2026 - Pending Journal Publication
    %
    %   Stokes, P. A., Rath, P., Possidente, T., He, M., Purcell, S.,
    %   Manoach, D. S., Stickgold, R., Prerau, M. J.
    %   "Transient Oscillation Dynamics During Sleep Provide a Robust Basis
    %   for Electroencephalographic Phenotyping and Biomarker Identification"
    %   Sleep, 2022; zsac223. https://doi.org
    %
    % =========================================================================

    % ================= PUBLIC PROPERTIES =================
    properties
        N (1,1) double {mustBeNonnegative} = 0

        Colormap = 'turbo'
        ShowTimeRemaining (1,1) logical = true
        ShowPercentage (1,1) logical = true

        BarHeight (1,1) double {mustBePositive, mustBeLessThanOrEqual(BarHeight,1)} = 0.6

        FontSize (1,1) double = 11
        FontColor (1,3) double = [0.2 0.2 0.2]

        TimerPeriod (1,1) double {mustBePositive} = 0.05
        ShowTicks (1,1) logical = false
    end

    % ================= PRIVATE PROPERTIES =================
    properties (Access = private)
        Axes
        Bar
        BackgroundRect
        BorderRect

        Timer
        Current (1,1) double = 0
        AvgIterTime
        StartTime
        IsFinal (1,1) logical = false
    end

    % ================= SETUP =================
    methods (Access = protected)

        function setup(obj)
            % UIAxes (no manual parenting; ComponentContainer handles it)

            obj.Axes = uiaxes(obj);
            obj.Axes.Units = 'normalized';
            obj.Axes.Position = [0 0 1 1];

            obj.Axes.XLim = [0 100];
            obj.Axes.YLim = [0 1];

            obj.Axes.Color = 'none';
            obj.Axes.XColor = 'none';
            obj.Axes.YColor = 'none';
            obj.Axes.Toolbar.Visible = 'off';
            obj.Axes.NextPlot = 'add';
            obj.Axes.LooseInset = [0 0 0 0];

            disableDefaultInteractivity(obj.Axes)


            y0 = (1 - obj.BarHeight)/2;
            h  = obj.BarHeight;

            obj.BackgroundRect = rectangle(obj.Axes,...
                'Position',[0 y0 100 h],...
                'FaceColor',[0.94 0.94 0.94],...
                'EdgeColor',[0.8 0.8 0.8],...
                'LineWidth',1.5);

            % Progress bar
            obj.Bar = rectangle(obj.Axes,...
                'Position',[0 y0 0 h],...
                'FaceColor',[0 0.4470 0.7410],...
                'EdgeColor','none');

            % Border
            obj.BorderRect = rectangle(obj.Axes,...
                'Position',[0 y0 0 h],...
                'FaceColor','none',...
                'EdgeColor',[0.7 0.7 0.7],...
                'LineWidth',1);

            obj.preFirst();
        end

        function update(obj)
            obj.updateAppearance();
        end
    end

    % ================= PUBLIC METHODS =================
    methods

        function start(obj)
            obj.cleanupTimer();

            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.StartTime = tic;
            obj.IsFinal = false;

            obj.preFirst();

            obj.Timer = timer( ...
                'ExecutionMode','fixedRate', ...
                'Period',obj.TimerPeriod, ...
                'TimerFcn',@(~,~)obj.updateDisplay());

            start(obj.Timer);
        end

        function updateIteration(obj, iteration)
            if iteration > obj.N
                error('Iteration exceeds N');
            end

            obj.Current = iteration;

            if ~isempty(obj.StartTime)
                t_elapsed = toc(obj.StartTime);
                current_iter_time = t_elapsed / max(iteration,1);

                if iteration == 1
                    obj.AvgIterTime = current_iter_time;
                else
                    alpha = 0.05;
                    obj.AvgIterTime = alpha * current_iter_time + (1-alpha) * obj.AvgIterTime;
                end
            end
        end

        function complete(obj)
            obj.cleanupTimer();
            obj.Current = obj.N;
            obj.IsFinal = true;

            cmap = colormap(obj.Axes, obj.Colormap);
            obj.Bar.FaceColor = cmap(end,:);

            obj.updateBar(100);
            obj.updateTitle(100,'--:--');
        end

        function refresh(obj)
            obj.cleanupTimer();

            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.StartTime = [];
            obj.IsFinal = false;

            obj.Bar.FaceColor = [0 0.4470 0.7410];
            obj.preFirst();
        end
    end

    % ================= INTERNAL =================
    methods (Access = private)

        function preFirst(obj)
            obj.updateBar(0);
            obj.updateTitle(0,'--:--');
        end

        function updateDisplay(obj)
            if isempty(obj.StartTime)
                return
            end

            if isempty(obj.AvgIterTime)
                pct = 0;
                t_remain = '--:--';
            else
                t_elapsed = toc(obj.StartTime);

                avg = max(obj.AvgIterTime, eps);
                pct = min(100, (t_elapsed / (avg * obj.N)) * 100);

                remaining = max(avg * obj.N - t_elapsed, 0);
                t_remain = char(duration(0,0,remaining,'Format','mm:ss'));
            end

            obj.updateTitle(pct,t_remain);

            cmap = colormap(obj.Axes, obj.Colormap);
            idx = max(1, round((pct/100)*size(cmap,1)));
            obj.Bar.FaceColor = cmap(idx,:);

            obj.updateBar(pct);

            drawnow limitrate

            if obj.Current >= obj.N && ~obj.IsFinal
                obj.complete();
            end
        end

        function updateBar(obj, pct)

            y0 = (1 - obj.BarHeight)/2;
            h  = obj.BarHeight;

            % Background
            obj.BackgroundRect.Position = [0 y0 100 h];

            % Fill
            obj.Bar.Position = [0 y0 pct h];

            % Border
            obj.BorderRect.Position = [0 y0 pct h];

        end

        function updateTitle(obj, pct, t_remain)
            str = sprintf('Progress: %d/%d', obj.Current, obj.N);

            if obj.ShowPercentage
                str = sprintf('%s  %.1f%%', str, pct);
            end

            if obj.ShowTimeRemaining
                str = sprintf('%s | Time Remaining: %s', str, t_remain);
            end

            title(obj.Axes, str, ...
                'FontSize', obj.FontSize, ...
                'FontWeight','bold', ...
                'Color', obj.FontColor);
        end

        function updateAppearance(obj)
            if obj.ShowTicks
                obj.Axes.XColor = [0 0 0];
                obj.Axes.XTick = 0:10:100;
            else
                obj.Axes.XColor = 'none';
                obj.Axes.XTick = [];
            end
        end

        function cleanupTimer(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
            end
            obj.Timer = [];
        end
    end
end