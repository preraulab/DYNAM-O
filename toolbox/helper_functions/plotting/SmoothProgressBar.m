classdef SmoothProgressBar < handle
% SmoothProgressBar - Smooth animated horizontal progress bar for MATLAB apps
%
% This class provides a continous time progress bar for uifigure-based
% applications. It supports continuous-time polling between discrete
% iteration updates using a generalized sigmoid interpolation. The bar can
% display a color gradient based on a colormap, optional percentage, time
% remaining, and x-axis tick marks. The progress bar can be refreshed to
% restart from zero or forced to complete instantly.
%
% Usage:
%   pb = SmoothProgressBar(parent, N)
%   pb = SmoothProgressBar(parent, N, position)
%   pb = SmoothProgressBar(parent, N, position, colormap_name)
%   pb = SmoothProgressBar(parent, N, position, colormap_name, show_ticks)
%
% Inputs:
%   parent        - uifigure or uipanel handle where the progress bar is displayed
%   N             - Total number of iterations or work units (positive scalar)
%   position      - [x y width height] position of the axes (default: [50 100 400 40])
%   colormap_name - String name of MATLAB colormap for bar gradient (default: 'turbo')
%   show_ticks    - Logical: display x-axis ticks (default: false)
%
% Properties (Access = public):
%   Parent             - Parent UI container
%   Axes               - UIAxes object used for rendering the progress bar
%   Bar                - Patch object representing the filled portion of the bar
%   N                  - Total number of iterations
%   Current            - Last completed iteration index
%   AvgIterTime        - Exponentially averaged iteration duration (seconds)
%   Timer              - Timer object used for smooth updates
%   Colormap           - Name of colormap for progress coloring
%   ShowTicks          - Toggle x-axis tick marks
%   ShowTimeRemaining  - Toggle time remaining display in title
%   ShowPercentage     - Toggle percentage display in title
%   BarHeight          - Relative bar height (0–1)
%   FontSize           - Title font size
%   FontColor          - Title font color (RGB)
%   Position           - Axes position [x y width height] (dependent)
%
% Methods:
%   start()            - Start or restart the timer and begin smooth updates
%   updateIteration(k) - Notify the bar that iteration k has completed
%   complete()         - Force the progress bar to complete immediately
%   refresh()          - Reset the progress bar to zero and clear statistics
%
% Continuous-time interpolation:
%   The bar advances continuously using a timer-driven update loop. For iteration
%   k, the displayed progress fraction p(t) is computed via:
%
%       p(t) = a + (b - a) / (1 + exp(-kappa * t))
%
%   where:
%       a = k / N
%       b = (k + 1) / N
%       t = elapsed time since iteration k completed
%       kappa = scaling factor determined to span approximately one iteration
%
%   This produces a smooth visual progression without discrete jumps.
%   Remaining time is estimated as T_remaining = max(N * AvgIterTime - elapsed, 0).
%
% Example:
%   fig = uifigure('Position',[100 100 600 250]);
%   N = 50;
%
%   pb = SmoothProgressBar(fig, N, [100 120 400 40], 'turbo', true);
%   pb.ShowPercentage = true;
%   pb.ShowTimeRemaining = true;
%
%   pb.start();
%
%   for k = 1:N
%       pause(0.04 + 0.02*rand); % Simulate work
%       pb.updateIteration(k);
%   end
%
%   pause(1);
%   pb.refresh();
%   pb.start();
%
%   for k = 1:N
%       pause(0.03);
%       pb.updateIteration(k);
%   end



    properties (Access = public)
        Parent
        Axes
        Bar
        N
        Current
        AvgIterTime
        StartTime
        Timer
        Colormap
        ShowTicks
        ShowTimeRemaining
        ShowPercentage
        BarHeight
        BorderRadius
        FontSize
        FontColor
    end

    properties (Access = private)
        PositionValue
        IsFinal = false
        BackgroundRect
        BorderRect
    end

    properties (Dependent)
        Position
    end

    methods
        function obj = SmoothProgressBar(parent, N, position, colormap_name, show_ticks)
            % Constructor

            %---------------- Validate iteration count ----------------%
            if nargin < 2 || isempty(N) || ~isscalar(N) || N <= 0
                error('SmoothProgressBar:InvalidInput', ...
                    'N must be a positive scalar.');
            end
            obj.N = N;
            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.Timer = [];

            %---------------- Handle position argument ----------------%
            if nargin < 3 || isempty(position)
                position = [50 100 400 40];
            end
            obj.PositionValue = position;

            %---------------- Handle colormap argument ----------------%
            if nargin < 4 || isempty(colormap_name)
                colormap_name = 'turbo';
            end
            obj.Colormap = colormap_name;

            %---------------- Handle tick visibility ------------------%
            if nargin < 5 || isempty(show_ticks)
                show_ticks = false;
            end
            obj.ShowTicks = show_ticks;

            %---------------- Display defaults ------------------------%
            obj.ShowTimeRemaining = true;
            obj.ShowPercentage = true;
            obj.BarHeight = 0.6;
            obj.BorderRadius = 0.15;
            obj.FontSize = 11;
            obj.FontColor = [0.2 0.2 0.2];

            %****************************************************************
            %                           CREATE AXES
            %****************************************************************
            obj.Parent = parent;
            obj.Axes = uiaxes(parent, 'Position', position);
            obj.Axes.XLim = [0 100];
            obj.Axes.YLim = [0 1];
            obj.Axes.Color = 'none';
            obj.Axes.XColor = 'none';
            obj.Axes.YColor = 'none';
            obj.Axes.Toolbar.Visible = 'off';
            obj.Axes.NextPlot = 'add';
            disableDefaultInteractivity(obj.Axes)

            %****************************************************************
            %                    CREATE BACKGROUND ELEMENTS
            %****************************************************************
            obj.BackgroundRect = rectangle(obj.Axes, ...
                'Position', [0 (1-obj.BarHeight)/2 100 obj.BarHeight], ...
                'FaceColor', [0.94 0.94 0.94], ...
                'EdgeColor', [0.8 0.8 0.8], ...
                'LineWidth', 1.5);

            obj.Bar = patch(obj.Axes, ...
                [0 0 0 0], ...
                [0.5 0.5 1.5 1.5], ...
                [0 0.4470 0.7410], ...
                'EdgeColor', 'none');

            obj.BorderRect = rectangle(obj.Axes, ...
                'Position', [0 (1-obj.BarHeight)/2 0 obj.BarHeight], ...
                'FaceColor', 'none', ...
                'EdgeColor', [0.7 0.7 0.7], ...
                'LineWidth', 1);

            title(obj.Axes, 'Progress', ...
                'FontSize', obj.FontSize, ...
                'FontWeight', 'bold', ...
                'Color', obj.FontColor)

            obj.preFirst();
        end

        %************************************************************
        %                     INITIAL RESET STATE
        %************************************************************
        function preFirst(obj)
            obj.Current = 0;
            obj.Bar.XData = [0 0 0 0];
            obj.Bar.YData = [0.5 0.5 1.5 1.5];
            obj.updateTitle(0);
            drawnow limitrate
        end

        %************************************************************
        %                        START TIMER
        %************************************************************
        function start(obj)
            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.IsFinal = false;
            obj.StartTime = tic;

            obj.preFirst();

            obj.Timer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.05, ...
                'TimerFcn', @(~,~)obj.updateDisplay());
            start(obj.Timer);
        end

        %************************************************************
        %                 ITERATION COMPLETION UPDATE
        %************************************************************
        function updateIteration(obj, iteration)
            if iteration > obj.N
                error('SmoothProgressBar:IterationExceeded', ...
                    'iteration > N');
            end
            obj.Current = iteration;

            if ~isempty(obj.StartTime)
                t_elapsed = toc(obj.StartTime);
                current_iter_time = t_elapsed / iteration;
                if iteration == 1
                    obj.AvgIterTime = current_iter_time;
                else
                    alpha = 0.05;
                    obj.AvgIterTime = ...
                        alpha * current_iter_time + ...
                        (1 - alpha) * obj.AvgIterTime;
                end
            end
        end

        %************************************************************
        %                 SMOOTH DISPLAY UPDATE (TIMER)
        %************************************************************
        function updateDisplay(obj)
            if isempty(obj.StartTime)
                return
            end

            if isempty(obj.AvgIterTime)
                pct = 0;
                t_remain_str = '--:--';
            else
                t_elapsed = toc(obj.StartTime);
                c_iter = obj.Current;

                a = c_iter / obj.N;
                b = (c_iter + 1) / obj.N;
                avg_time = max(obj.AvgIterTime, eps);
                d = avg_time / 2;

                t_iter = t_elapsed - c_iter * avg_time;
                t_iter = max(-d, min(t_iter - d, d));
                c_offset = 0.05 / obj.N;

                pct = SmoothProgressBar.generalized_sigmoid( ...
                    t_iter, a, b, c_offset, d) * 100;
                pct = min(pct, 100);

                remaining = max(avg_time * obj.N - t_elapsed, 0);
                t_remain_str = char(duration( ...
                    0, 0, remaining, 'Format', 'mm:ss'));
            end

            obj.updateTitle(pct, t_remain_str);

            cmap = colormap(obj.Axes, obj.Colormap);
            idx = max(1, round((pct / 100) * size(cmap, 1)));
            obj.Bar.FaceColor = cmap(idx, :);

            obj.Bar.XData = [0 pct pct 0];
            obj.Bar.YData = [(1-obj.BarHeight)/2 ...
                             (1-obj.BarHeight)/2 ...
                             (1+obj.BarHeight)/2 ...
                             (1+obj.BarHeight)/2];
            obj.BorderRect.Position = ...
                [0 (1-obj.BarHeight)/2 pct obj.BarHeight];

            drawnow limitrate

            if obj.Current >= obj.N && pct >= 100 && ~obj.IsFinal
                obj.IsFinal = true;
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
                title(obj.Axes, 'Process Complete!', ...
                    'FontSize', obj.FontSize, ...
                    'FontWeight', 'bold', ...
                    'Color', obj.FontColor);
            end
        end

        %************************************************************
        %                        TITLE UPDATE
        %************************************************************
        function updateTitle(obj, pct, varargin)
            title_str = sprintf('Progress: %d/%d', ...
                obj.Current, obj.N);

            if obj.ShowPercentage
                title_str = sprintf('%s  %0.1f%%', ...
                    title_str, pct);
            end

            if obj.ShowTimeRemaining && ~isempty(varargin)
                title_str = sprintf('%s | Time Remaining: %s', ...
                    title_str, varargin{1});
            end

            title(obj.Axes, title_str, ...
                'FontSize', obj.FontSize, ...
                'FontWeight', 'bold', ...
                'Color', obj.FontColor);
        end

        %************************************************************
        %                       FORCE COMPLETION
        %************************************************************
        function complete(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
            obj.IsFinal = true;
            obj.Current = obj.N;

            cmap = colormap(obj.Axes, obj.Colormap);
            obj.Bar.FaceColor = cmap(end, :);
            obj.Bar.XData = [0 100 100 0];
            obj.BorderRect.Position = ...
                [0 (1-obj.BarHeight)/2 100 obj.BarHeight];

            title(obj.Axes, 'Process Complete!', ...
                'FontSize', obj.FontSize, ...
                'FontWeight', 'bold', ...
                'Color', obj.FontColor);
            drawnow limitrate
        end

        %************************************************************
        %                        FULL RESET
        %************************************************************
        function refresh(obj)
            %REFRESH  Reset the progress bar to an unused initial state
            %
            %   Stops and deletes any running timer, clears timing
            %   statistics, resets progress to zero, and restores the
            %   initial visual appearance. Call START afterwards to
            %   begin a new run.
            %
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end

            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.StartTime = [];
            obj.IsFinal = false;

            obj.Bar.FaceColor = [0 0.4470 0.7410];
            obj.preFirst();
        end
    end

    %************************************************************
    %                    PROPERTY ACCESSORS
    %************************************************************
    methods
        function set.Position(obj, val)
            validateattributes(val, {'numeric'}, {'numel', 4});
            obj.PositionValue = val;
            if ~isempty(obj.Axes) && isvalid(obj.Axes)
                obj.Axes.Position = val;
            end
        end

        function val = get.Position(obj)
            val = obj.PositionValue;
        end

        function set.ShowTicks(obj, val)
            validateattributes(val, {'logical'}, {'scalar'});
            obj.ShowTicks = val;
            if ~isempty(obj.Axes)
                obj.updateTickVisibility();
            end
        end

        function set.FontSize(obj, val)
            validateattributes(val, {'numeric'}, {'scalar','positive'});
            obj.FontSize = val;
        end

        function set.FontColor(obj, val)
            validateattributes(val, {'numeric'}, {'numel',3});
            obj.FontColor = val;
        end

        function set.BarHeight(obj, val)
            validateattributes(val, {'numeric'}, ...
                {'scalar','positive','<=',1});
            obj.BarHeight = val;
        end
    end

    %************************************************************
    %                    STATIC UTILITIES
    %************************************************************
    methods (Static, Access = private)
        function y = generalized_sigmoid(x, a, b, c, d)
            k = (1/d) * log((b - a - c) / c);
            y = a + (b - a) ./ (1 + exp(-k .* x));
        end
    end
end
