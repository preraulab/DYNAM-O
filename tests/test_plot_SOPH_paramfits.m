classdef test_plot_SOPH_paramfits < matlab.uitest.TestCase
    %TEST_PLOT_SOPH_PARAMFITS  Contour visibility and hover routing.

    methods (TestClassSetup)
        function add_repo_to_path(testCase) %#ok<MANU>
            this_dir = fileparts(mfilename('fullpath'));
            repo_root = fileparts(this_dir);
            if isempty(which('plot_SOPH_paramfits'))
                addpath(repo_root);
                addpath(genpath(fullfile(repo_root, 'toolbox')));
            end
        end
    end

    methods (Test)
        function mode_contours_start_hidden(testCase)
            [f, power_ax, phase_ax] = testCase.create_test_plot();
            testCase.addTeardown(@() close(f));

            power_contours = getappdata(power_ax, 'power_contours');
            phase_contours = getappdata(phase_ax, 'phase_contours');
            testCase.assertNumElements(power_contours, 1);
            testCase.assertNumElements(phase_contours, 1);
            testCase.verifyEqual(string(power_contours.Visible), "off");
            testCase.verifyEqual(string(phase_contours.Visible), "off");
        end

        function hover_routes_between_mode_axes(testCase)
            [f, power_ax, phase_ax] = testCase.create_test_plot();
            testCase.addTeardown(@() close(f));

            power_contours = getappdata(power_ax, 'power_contours');
            phase_contours = getappdata(phase_ax, 'phase_contours');

            f.CurrentAxes = phase_ax;
            testCase.hover(power_ax, [0.15, 3]);
            drawnow;
            testCase.verifyEqual(string(power_contours.Visible), "on");
            testCase.verifyEqual(string(phase_contours.Visible), "off");

            f.CurrentAxes = power_ax;
            testCase.hover(phase_ax, [0.15, 3]);
            drawnow;
            testCase.verifyEqual(string(power_contours.Visible), "off");
            testCase.verifyEqual(string(phase_contours.Visible), "on");

            testCase.hover(power_ax, [1.8, 4.8]);
            drawnow;
            testCase.verifyEqual(string(power_contours.Visible), "off");
            testCase.verifyEqual(string(phase_contours.Visible), "off");

            % An exact marker hit must still activate its contour.
            testCase.hover(power_ax, [0, 3]);
            drawnow;
            testCase.verifyEqual(string(power_contours.Visible), "on");
            testCase.verifyEqual(string(phase_contours.Visible), "off");

            testCase.press(power_ax, [0, 3]);
            drawnow;
            data_tips = findall(f, '-isa', 'matlab.graphics.datatip.DataTip');
            testCase.verifyNumElements(data_tips, 1);
        end
    end

    methods (Access = private)
        function [f, power_ax, phase_ax] = create_test_plot(~)
            old_visibility = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'on');
            visibility_cleanup = onCleanup( ...
                @() set(groot, 'DefaultFigureVisible', old_visibility));

            power_bins = linspace(-2, 2, 9);
            phase_bins = linspace(-pi, pi, 9);
            freq_bins = linspace(1, 5, 9);
            power_params = [1, 3, 0.5, 0, 0.5, 0];
            phase_params = [0.1, 3, 0.5, 0, 1, 0];

            [power_grid, freq_grid] = meshgrid(power_bins, freq_bins);
            model_power = rotGauss(power_grid, freq_grid, power_params(1), ...
                power_params(2), power_params(3), power_params(4), ...
                power_params(5), power_params(6)) + 0.01;
            [phase_grid, freq_grid] = meshgrid(phase_bins, freq_bins);
            model_phase = normalized_vmGauss(phase_grid, freq_grid, true, ...
                0, 0, 0.01, phase_params(1), phase_params(2), ...
                phase_params(3), phase_params(4), phase_params(5), ...
                phase_params(6));

            power_type = fittype( ...
                ['rotGauss(x,y,amp_1,fmean_1,fstd_1,pmean_1,pstd_1,' ...
                 'theta_1)+xxx*x+yyy*y+zzz'], ...
                'independent', {'x', 'y'}, 'dependent', 'z');
            power_fitobj = sfit(power_type, power_params(1), ...
                power_params(2), power_params(3), power_params(4), ...
                power_params(5), power_params(6), 0, 0, 0.01);

            phase_type = fittype( ...
                ['normalized_vmGauss(x,y,unit_row,xxx,yyy,zzz,amp_1,' ...
                 'fmean_1,fstd_1,phasepref_1,recikappa_1,theta_1)'], ...
                'independent', {'x', 'y'}, 'dependent', 'z', ...
                'problem', 'unit_row');
            phase_fitobj = sfit(phase_type, phase_params(1), ...
                phase_params(2), phase_params(3), phase_params(4), ...
                phase_params(5), phase_params(6), 0, 0, 0.01, true);

            plot_SOPH_paramfits( ...
                power_bins, zeros(numel(freq_bins), numel(power_bins)), ...
                model_power', model_power, power_params, [5, 95], ...
                [-2, 2], [1, 5], ...
                phase_bins, zeros(numel(freq_bins), 3*numel(phase_bins)), ...
                model_phase', model_phase, phase_params, [5, 95], ...
                [-pi, pi], [1, 5], freq_bins, power_fitobj, phase_fitobj);

            f = gcf;
            drawnow;
            power_ax = getappdata(f, 'power_ax');
            phase_ax = getappdata(f, 'phase_ax');
        end
    end
end
