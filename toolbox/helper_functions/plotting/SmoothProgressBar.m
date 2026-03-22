classdef SmoothProgressBar < handle
    % SmoothProgressBar - Smooth animated horizontal progress bar for MATLAB apps
    %
    %   This class provides a continuous-time progress bar for uifigure-based
    %   applications. The bar advances smoothly between iteration updates using a
    %   generalized sigmoid interpolation. It supports a color gradient, optional
    %   percentage display, time remaining, and x-axis tick marks.
    %
    % USAGE:
    %   pb = SmoothProgressBar(parent, N)
    %   pb = SmoothProgressBar(parent, N, position)
    %   pb = SmoothProgressBar(parent, N, position, colormap_name)
    %   pb = SmoothProgressBar(parent, N, position, colormap_name, show_ticks)
    %
    % INPUTS:
    %   parent        - uifigure or uipanel handle for displaying the progress bar
    %   N             - Total number of iterations or work units (positive scalar)
    %   position      - [x y width height] of the axes (default: [50 100 400 40])
    %   colormap_name - Name of MATLAB colormap for bar gradient (default: 'turbo')
    %   show_ticks    - Logical: display x-axis ticks (default: false)
    %
    % PUBLIC PROPERTIES:
    %   Parent             - Parent UI container
    %   Axes               - UIAxes used for rendering
    %   Bar                - Patch object representing filled portion
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
    %   N = 10;
    %
    %   pb = SmoothProgressBar(fig, N, [100 120 400 60], 'turbo');
    %   pb.ShowPercentage = true;
    %   pb.ShowTimeRemaining = true;
    %
    %   pb.start();
    %   for k = 1:N
    %       pause(2 + rand); % Simulate work
    %       pb.updateIteration(k);
    %   end
    %
    %   pause(1);
    %   pb.refresh();
    %   pb.TimerPeriod = 1; % slower updates
    %   pb.start();
    %
    %   for k = 1:N
    %      pause(2 + rand); % Simulate work
    %       pb.updateIteration(k);
    %   end

    properties (Access = public)
        Parent
        Axes
        Bar
        N

        Timer
        Colormap
        ShowTimeRemaining
        ShowPercentage
        BarHeight
        FontSize
        FontColor
        TimerPeriod = 0.05; % default update rate
        ShowTicks = false;
    end

    properties (Access = private)
        PositionValue
        IsFinal = false
        BackgroundRect
        BorderRect

        Current
        AvgIterTime
        StartTime
    end

    properties (Dependent)
        Position
    end

    methods (Access = public)
        function obj = SmoothProgressBar(parent, N, position, colormap_name, show_ticks)
            % Constructor
            if nargin < 2 || isempty(N) || ~isscalar(N) || N <= 0
                error('SmoothProgressBar:InvalidInput', 'N must be a positive scalar.');
            end
            obj.N = N;
            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.Timer = [];

            if nargin < 3 || isempty(position)
                position = [50 100 400 40];
            end
            obj.PositionValue = position;

            if nargin < 4 || isempty(colormap_name)
                colormap_name = 'turbo';
            end
            obj.Colormap = colormap_name;

            if nargin < 5 || isempty(show_ticks)
                show_ticks = false;
            end
            obj.ShowTicks = show_ticks;

            obj.ShowTimeRemaining = true;
            obj.ShowPercentage = true;
            obj.BarHeight = 0.6;
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

            obj.toggleTickVisibility();
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

            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
            end

            obj.Timer = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period', obj.TimerPeriod, ...
                'TimerFcn', @(~,~)obj.updateDisplay());
            start(obj.Timer);
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
            obj.BorderRect.Position = [0 (1-obj.BarHeight)/2 100 obj.BarHeight];

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

        %************************************************************
        %                 ITERATION COMPLETION UPDATE
        %************************************************************
        function updateIteration(obj, iteration)
            if iteration > obj.N
                error('SmoothProgressBar:IterationExceeded', 'iteration > N');
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
    end

    methods (Access = private)
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

                pct = SmoothProgressBar.generalized_sigmoid(t_iter, a, b, c_offset, d) * 100;
                pct = min(pct, 100);

                remaining = max(avg_time * obj.N - t_elapsed, 0);
                t_remain_str = char(duration(0, 0, remaining, 'Format', 'mm:ss'));
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
            obj.BorderRect.Position = [0 (1-obj.BarHeight)/2 pct obj.BarHeight];

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
            title_str = sprintf('Progress: %d/%d', obj.Current, obj.N);

            if obj.ShowPercentage
                title_str = sprintf('%s  %0.1f%%', title_str, pct);
            end

            if obj.ShowTimeRemaining && ~isempty(varargin)
                title_str = sprintf('%s | Time Remaining: %s', title_str, varargin{1});
            end

            title(obj.Axes, title_str, ...
                'FontSize', obj.FontSize, ...
                'FontWeight', 'bold', ...
                'Color', obj.FontColor);
        end

        %************************************************************
        %               TOGGLE X-AXIS TICK VISIBILITY
        %************************************************************
        function toggleTickVisibility(obj)
            if obj.ShowTicks
                obj.Axes.XColor = [0 0 0];
                obj.Axes.XTick = 0:10:100;
            else
                obj.Axes.XColor = 'none';
                obj.Axes.XTick = [];
            end
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
            if ~isempty(obj.Axes) %#ok<*MCSUP>
                obj.toggleTickVisibility();
            end
        end

        function set.TimerPeriod(obj, val)
            validateattributes(val, {'numeric'}, {'scalar','positive'});
            obj.TimerPeriod = val;
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                obj.Timer.Period = val;
                start(obj.Timer);
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
            validateattributes(val, {'numeric'}, {'scalar','positive','<=',1});
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
