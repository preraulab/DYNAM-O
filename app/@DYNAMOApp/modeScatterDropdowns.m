function [xDD, yDD, sDD, cDD, zDD] = modeScatterDropdowns(app, axisKind)
    % modeScatterDropdowns  Resolve the X/Y/Size/Color/Z dropdown
    %   handles for one axis kind ('power' | 'phase'). Both
    %   groups live in the single Mode Scatter tab. The Z handle
    %   is the 5th return so legacy 4-output callers still work.
    switch axisKind
        case 'power'
            xDD = app.ModeScatterPowerXDropDown;
            yDD = app.ModeScatterPowerYDropDown;
            sDD = app.ModeScatterPowerSizeDropDown;
            cDD = app.ModeScatterPowerColorDropDown;
            zDD = app.ModeScatterPowerZDropDown;
        case 'phase'
            xDD = app.ModeScatterPhaseXDropDown;
            yDD = app.ModeScatterPhaseYDropDown;
            sDD = app.ModeScatterPhaseSizeDropDown;
            cDD = app.ModeScatterPhaseColorDropDown;
            zDD = app.ModeScatterPhaseZDropDown;
        otherwise
            error('modeScatterDropdowns:badAxis', ...
                  'axisKind must be ''power'' or ''phase''.');
    end
end
