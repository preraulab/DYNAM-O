classdef SmoothProgressBar < handle
    %SMOOTHPROGRESSBAR  Professional smooth horizontal progress bar for apps
    %
    %   PB = SmoothProgressBar(PARENT, N, POSITION)
    %   PB = SmoothProgressBar(PARENT, N, POSITION, COLORMAP)
    %   PB = SmoothProgressBar(PARENT, N, POSITION, COLORMAP, SHOWTICKS)
    %
    %   Creates a professional smooth progress bar using a sigmoid curve for animation.
    %   The bar color changes based on progress using the specified colormap.

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
            if nargin < 2 || isempty(N) || ~isscalar(N) || N <= 0
                error('SmoothProgressBar:InvalidInput', 'N must be a positive scalar.');
            end
            obj.N = N;
            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.Timer = [];

            % Handle position argument
            if nargin < 3 || isempty(position)
                position = [50 100 400 40];
            end
            obj.PositionValue = position;

            % Handle colormap argument
            if nargin < 4 || isempty(colormap_name)
                colormap_name = 'turbo';
            end
            obj.Colormap = colormap_name;

            % Handle show_ticks argument
            if nargin < 5 || isempty(show_ticks)
                show_ticks = false;
            end
            obj.ShowTicks = show_ticks;

            % Set display options
            obj.ShowTimeRemaining = true;
            obj.ShowPercentage = true;
            obj.BarHeight = 0.6;
            obj.BorderRadius = 0.15;
            obj.FontSize = 11;
            obj.FontColor = [0.2 0.2 0.2];

            % Create axes
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

            % Configure ticks
            obj.updateTickVisibility();

            % Create background rectangle for professional look
            obj.BackgroundRect = rectangle(obj.Axes, 'Position', [0 (1-obj.BarHeight)/2 100 obj.BarHeight], ...
                'FaceColor', [0.94 0.94 0.94], 'EdgeColor', [0.8 0.8 0.8], 'LineWidth', 1.5);

            % Create progress bar patch
            obj.Bar = patch(obj.Axes, [0 0 0 0], [0.5 0.5 1.5 1.5], [0 0.4470 0.7410], 'EdgeColor', 'none');

            % Create border rectangle for polished edge
            obj.BorderRect = rectangle(obj.Axes, 'Position', [0 (1-obj.BarHeight)/2 0 obj.BarHeight], ...
                'FaceColor', 'none', 'EdgeColor', [0.7 0.7 0.7], 'LineWidth', 1);

            title(obj.Axes, 'Progress', 'FontSize', obj.FontSize, 'FontWeight', 'bold', 'Color', obj.FontColor)
            obj.preFirst();
        end

        function updateTickVisibility(obj)
            % Update tick visibility based on ShowTicks property
            if obj.ShowTicks
                obj.Axes.XTick = 0:10:100;
                obj.Axes.XTickLabel = string(0:10:100);
                obj.Axes.XAxis.FontSize = obj.FontSize - 1;
                obj.Axes.XAxis.Color = [0.5 0.5 0.5];
            else
                obj.Axes.XTick = [];
                obj.Axes.XTickLabel = {};
            end
            obj.Axes.YTick = [];
            obj.Axes.YTickLabel = {};
        end

        function preFirst(obj)
            obj.Current = 0;
            obj.Bar.XData = [0 0 0 0];
            obj.Bar.YData = [0.5 0.5 1.5 1.5];
            obj.updateTitle(0);
            drawnow limitrate
        end

        function start(obj)
            obj.Current = 0;
            obj.AvgIterTime = [];
            obj.IsFinal = false;
            obj.StartTime = tic;

            obj.preFirst();

            % Create timer for smooth updates
            obj.Timer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.05, ...
                'TimerFcn', @(~,~)obj.updateDisplay());
            start(obj.Timer);
        end

        function updateIteration(obj, iteration)
            % Called when iteration completes
            if iteration > obj.N
                error('SmoothProgressBar:IterationExceeded', 'iteration > N');
            end
            obj.Current = iteration;

            % Update average iteration time
            if ~isempty(obj.StartTime)
                t_elapsed = toc(obj.StartTime);
                current_iter_time = t_elapsed / iteration;
                if iteration == 1
                    obj.AvgIterTime = current_iter_time;
                else
                    alpha = 0.05;
                    obj.AvgIterTime = alpha * current_iter_time + (1 - alpha) * obj.AvgIterTime;
                end
            end
        end

        function updateDisplay(obj)
            % Called by timer to smoothly update the display
            if isempty(obj.StartTime)
                return
            end

            if isempty(obj.AvgIterTime)
                pct = 0;
                t_remain_str = '--:--';
            else
                t_elapsed = toc(obj.StartTime);

                % Compute smooth percentage using sigmoid
                c_iter = obj.Current;
                a = c_iter / obj.N;
                b = (c_iter + 1) / obj.N;
                avg_time = obj.AvgIterTime;
                if ~isfinite(avg_time) || avg_time <= 0
                    avg_time = eps;
                end
                d = avg_time / 2;
                t_iter = t_elapsed - c_iter * avg_time;
                t_iter = max(-d, min(t_iter - d, d));
                c_offset = 0.05 / obj.N;

                pct = SmoothProgressBar.generalized_sigmoid(t_iter, a, b, c_offset, d) * 100;
                pct = min(pct, 100);

                % Compute remaining time
                est_total_time = avg_time * obj.N;
                remaining = max(est_total_time - t_elapsed, 0);
                t_remain_str = char(duration(0, 0, remaining, 'Format', 'mm:ss'));
            end

            % Update title with conditional display options
            obj.updateTitle(pct, t_remain_str);

            % Get color from colormap based on progress
            cmap = colormap(obj.Axes, obj.Colormap);
            color_idx = max(1, round((pct / 100) * size(cmap, 1)));
            bar_color = cmap(color_idx, :);

            % Update patch position and color with smooth animation
            bar_width = pct;
            obj.Bar.XData = [0 bar_width bar_width 0];
            obj.Bar.YData = [(1-obj.BarHeight)/2 (1-obj.BarHeight)/2 (1+obj.BarHeight)/2 (1+obj.BarHeight)/2];
            obj.Bar.FaceColor = bar_color;

            % Update border rectangle
            obj.BorderRect.Position = [0 (1-obj.BarHeight)/2 bar_width obj.BarHeight];

            drawnow limitrate

            % Check if done
            if obj.Current >= obj.N && pct >= 100 && ~obj.IsFinal
                obj.IsFinal = true;
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
                title(obj.Axes, 'Process Complete!', 'FontSize', obj.FontSize, 'FontWeight', 'bold', ...
                    'Color', obj.FontColor);
            end
        end

        function updateTitle(obj, pct, varargin)
            % Update title with customizable display options
            title_str = sprintf('Progress: %d/%d', obj.Current, obj.N);

            if obj.ShowPercentage
                title_str = sprintf('%s %0.1f%%', title_str, pct);
            end

            if obj.ShowTimeRemaining && ~isempty(varargin)
                t_remain_str = varargin{1};
                title_str = sprintf('%s | Time Remaining: %s', title_str, t_remain_str);
            end

            title(obj.Axes, title_str, 'FontSize', obj.FontSize, 'FontWeight', 'bold', 'Color', obj.FontColor);
        end

        function complete(obj)
            % Force completion
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
            obj.IsFinal = true;
            obj.Current = obj.N;
            title(obj.Axes, 'Process Complete!', 'FontSize', obj.FontSize, 'FontWeight', 'bold', ...
                'Color', obj.FontColor);

            % Set to final color in colormap
            cmap = colormap(obj.Axes, obj.Colormap);
            obj.Bar.FaceColor = cmap(end, :);

            obj.Bar.XData = [0 100 100 0];
            obj.Bar.YData = [(1-obj.BarHeight)/2 (1-obj.BarHeight)/2 (1+obj.BarHeight)/2 (1+obj.BarHeight)/2];
            obj.BorderRect.Position = [0 (1-obj.BarHeight)/2 100 obj.BarHeight];
            drawnow limitrate
        end
    end

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
            validateattributes(val, {'numeric'}, {'scalar', 'positive'});
            obj.FontSize = val;
        end

        function set.FontColor(obj, val)
            validateattributes(val, {'numeric'}, {'numel', 3});
            obj.FontColor = val;
        end

        function set.BarHeight(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', 'positive', '<=', 1});
            obj.BarHeight = val;
        end
    end

    methods (Static, Access = private)
        function y = generalized_sigmoid(x, a, b, c, d)
            k = (1/d) * log((b - a - c) / c);
            y = a + (b - a) ./ (1 + exp(-k .* x));
        end
    end
end