classdef SmoothProgressBar < matlab.ui.componentcontainer.ComponentContainer
    % SmoothProgressBar - Smooth animated horizontal progress bar for MATLAB apps
    %
    %   This class provides a continuous-time progress bar for uifigure-based
    %   applications. The bar advances smoothly between iteration updates using a
    %   timer-driven display loop. It supports a color gradient, optional
    %   percentage display, time remaining, and x-axis tick marks.
    %
    % USAGE:
    %   pb = SmoothProgressBar(parent)          % set N later via pb.N = 10
    %   pb = SmoothProgressBar(parent, N)       % positional N  <-- works
    %   pb = SmoothProgressBar(parent, 'N', N)  % name-value N
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
    %   N                  - Total iterations
    %   Colormap           - Name of colormap (changes take effect immediately)
    %   ShowTimeRemaining  - Toggle time remaining display
    %   ShowPercentage     - Toggle percentage display
    %   BarHeight          - Relative bar height (0-1, changes take effect immediately)
    %   FontSize           - Title font size (changes take effect immediately)
    %   FontColor          - Title font color (changes take effect immediately)
    %   TimerPeriod        - Timer update period in seconds (default: 0.05)
    %   ShowTicks          - Show x-axis tick marks (changes take effect immediately)
    %
    % METHODS:
    %   start()            - Start or restart the timer
    %   updateIteration(k) - Notify the bar that iteration k has completed
    %   complete()         - Force the bar to complete immediately
    %   refresh()          - Reset the progress bar to zero
    %
    % EXAMPLE:
    %   fig = uifigure('Position',[100 100 600 250]);
    %   gl  = uigridlayout(fig,[3 1]);
    %
    %   pb = SmoothProgressBar(gl, 10);   % positional N works
    %   pb.Layout.Row = 2;
    %   pb.ShowPercentage    = true;
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
    % =========================================================================

    % ================= PUBLIC PROPERTIES =================
    properties
        N (1,1) double {mustBeNonnegative} = 0
        TimerPeriod (1,1) double {mustBePositive} = 0.05
    end

    properties (Access = public)
        Colormap          = 'turbo'
        ShowTimeRemaining (1,1) logical = true
        ShowPercentage    (1,1) logical = true
        ShowTicks         (1,1) logical = false
        BarHeight (1,1) double {mustBePositive, mustBeLessThanOrEqual(BarHeight,1)} = 0.6
        FontSize  (1,1) double = 11
        FontColor (1,3) double = [0.2 0.2 0.2]
    end

    % ================= PRIVATE PROPERTIES =================
    properties (Access = private)
        Axes_
        Bar_
        BackgroundRect_
        BorderRect_

        Timer_
        Current_      (1,1) double  = 0
        LastIterTime_               % tic token from previous updateIteration call
        AvgIterTime_                % EMA of per-iteration duration (seconds)
        StartTime_                  % tic token from start()
        IsFinal_      (1,1) logical = false
        LastPct_      (1,1) double  = 0
    end

    % ================= CONSTRUCTOR =================
    methods
        function obj = SmoothProgressBar(parent, varargin)
            % Supports positional N:  SmoothProgressBar(parent, 10)
            % as well as name-value:  SmoothProgressBar(parent, 'N', 10)
            %
            % ComponentContainer only accepts name-value pairs after parent,
            % so we detect a bare leading numeric scalar and convert it.
            if ~isempty(varargin) && isnumeric(varargin{1}) && isscalar(varargin{1})
                % Shift positional N into a name-value pair
                varargin = [{'N'}, varargin];
            end
            obj@matlab.ui.componentcontainer.ComponentContainer(parent, varargin{:});
        end
    end

    % ================= SETUP / UPDATE =================
    methods (Access = protected)

        function setup(obj)
            obj.Axes_ = uiaxes(obj);
            obj.Axes_.Units    = 'normalized';
            obj.Axes_.Position = [0 0 1 1];

            obj.Axes_.XLim = [0 100];
            obj.Axes_.YLim = [0 1];

            obj.Axes_.Color           = 'none';
            obj.Axes_.XColor          = 'none';
            obj.Axes_.YColor          = 'none';
            obj.Axes_.Toolbar.Visible = 'off';
            obj.Axes_.NextPlot        = 'add';
            obj.Axes_.LooseInset      = [0 0 0 0];

            disableDefaultInteractivity(obj.Axes_)

            y0 = (1 - obj.BarHeight) / 2;
            h  = obj.BarHeight;

            obj.BackgroundRect_ = rectangle(obj.Axes_, ...
                'Position',  [0 y0 100 h], ...
                'FaceColor', [0.94 0.94 0.94], ...
                'EdgeColor', [0.80 0.80 0.80], ...
                'LineWidth', 1.5);

            obj.Bar_ = rectangle(obj.Axes_, ...
                'Position',  [0 y0 0 h], ...
                'FaceColor', [0 0.4470 0.7410], ...
                'EdgeColor', 'none');

            % Border spans full width; only the outline edge is visible
            obj.BorderRect_ = rectangle(obj.Axes_, ...
                'Position',  [0 y0 100 h], ...
                'FaceColor', 'none', ...
                'EdgeColor', [0.7 0.7 0.7], ...
                'LineWidth', 1);

            obj.repositionGeometry_(0);
            obj.renderStatic_(0, '--:--');
        end

        % Called by ComponentContainer whenever any public property changes.
        function update(obj)
            if isempty(obj.Axes_) || ~isvalid(obj.Axes_)
                return
            end
            obj.applyTickVisibility_();
            obj.repositionGeometry_(obj.LastPct_);
            obj.renderStatic_(obj.LastPct_, '--:--');
        end
    end

    % ================= PUBLIC METHODS =================
    methods

        function start(obj)
            obj.cleanupTimer_();

            obj.Current_      = 0;
            obj.AvgIterTime_  = [];
            obj.LastIterTime_ = [];
            obj.StartTime_    = tic;
            obj.IsFinal_      = false;
            obj.LastPct_      = 0;

            obj.repositionGeometry_(0);
            obj.renderStatic_(0, '--:--');

            obj.Timer_ = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period',        obj.TimerPeriod, ...
                'TimerFcn',      @(~,~)obj.timerCallback_());

            start(obj.Timer_);
        end

        function updateIteration(obj, iteration)
            if iteration > obj.N
                error('SmoothProgressBar:iterationExceedsN', ...
                      'Iteration (%d) exceeds N (%d).', iteration, obj.N);
            end

            now_ = tic;

            % Measure the wall-clock time since the PREVIOUS updateIteration
            % call (true per-iteration cost, not a cumulative average).
            if ~isempty(obj.LastIterTime_)
                dt = toc(obj.LastIterTime_);
                if isempty(obj.AvgIterTime_)
                    obj.AvgIterTime_ = dt;
                else
                    alpha = 0.15;
                    obj.AvgIterTime_ = alpha * dt + (1 - alpha) * obj.AvgIterTime_;
                end
            end

            obj.LastIterTime_ = now_;
            obj.Current_      = iteration;
        end

        function complete(obj)
            obj.IsFinal_ = true;
            obj.cleanupTimer_();

            obj.Current_  = obj.N;
            obj.LastPct_  = 100;

            cmap = colormap(obj.Axes_, obj.Colormap);
            obj.Bar_.FaceColor = cmap(end, :);

            obj.repositionGeometry_(100);
            obj.renderStatic_(100, '00:00');
            drawnow limitrate
        end

        function refresh(obj)
            obj.cleanupTimer_();

            obj.Current_      = 0;
            obj.AvgIterTime_  = [];
            obj.LastIterTime_ = [];
            obj.StartTime_    = [];
            obj.IsFinal_      = false;
            obj.LastPct_      = 0;

            obj.Bar_.FaceColor = [0 0.4470 0.7410];

            obj.repositionGeometry_(0);
            obj.renderStatic_(0, '--:--');
            drawnow limitrate
        end
    end

    % ================= INTERNAL =================
    methods (Access = private)

        function timerCallback_(obj)
            if ~isvalid(obj)
                return
            end
            if isempty(obj.StartTime_)
                return
            end

            [pct, t_remain] = obj.computeProgress_();
            obj.LastPct_    = pct;

            cmap = colormap(obj.Axes_, obj.Colormap);
            idx  = max(1, round((pct / 100) * size(cmap, 1)));
            obj.Bar_.FaceColor = cmap(idx, :);

            obj.repositionGeometry_(pct);
            obj.renderStatic_(pct, t_remain);

            drawnow limitrate

            % Trigger completion once all iterations are reported
            if obj.Current_ >= obj.N && obj.N > 0 && ~obj.IsFinal_
                obj.complete();
            end
        end

        function [pct, t_remain] = computeProgress_(obj)
            if isempty(obj.AvgIterTime_) || obj.N == 0
                pct      = 0;
                t_remain = '--:--';
                return
            end

            t_elapsed = toc(obj.StartTime_);
            totalEst  = obj.AvgIterTime_ * obj.N;
            pct       = min(100, (t_elapsed / totalEst) * 100);

            remaining = max(totalEst - t_elapsed, 0);
            t_remain  = char(duration(0, 0, remaining, 'Format', 'mm:ss'));
        end

        function repositionGeometry_(obj, pct)
            y0 = (1 - obj.BarHeight) / 2;
            h  = obj.BarHeight;

            obj.BackgroundRect_.Position = [0 y0 100 h];
            obj.Bar_.Position            = [0 y0 pct h];
            obj.BorderRect_.Position     = [0 y0 100 h];
        end

        function renderStatic_(obj, pct, t_remain)
            str = sprintf('Progress: %d/%d', obj.Current_, obj.N);

            if obj.ShowPercentage
                str = sprintf('%s  %.1f%%', str, pct);
            end

            if obj.ShowTimeRemaining
                str = sprintf('%s | Time Remaining: %s', str, t_remain);
            end

            title(obj.Axes_, str, ...
                'FontSize',   obj.FontSize, ...
                'FontWeight', 'bold', ...
                'Color',      obj.FontColor);
        end

        function applyTickVisibility_(obj)
            if obj.ShowTicks
                obj.Axes_.XColor = [0 0 0];
                obj.Axes_.XTick  = 0:10:100;
            else
                obj.Axes_.XColor = 'none';
                obj.Axes_.XTick  = [];
            end
        end

        function cleanupTimer_(obj)
            if ~isempty(obj.Timer_) && isvalid(obj.Timer_)
                stop(obj.Timer_);
                delete(obj.Timer_);
            end
            obj.Timer_ = [];
        end
    end
end