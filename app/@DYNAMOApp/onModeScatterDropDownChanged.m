function onModeScatterDropDownChanged(app, ~)
    % onModeScatterDropDownChanged  Shared ValueChangedFcn for
    %   all eight Mode Scatter dropdowns (Power and Phase
    %   X/Y/Size/Color). The pair-grid layout is unified, so
    %   any change triggers a single redraw of the entire
    %   panel. The axis-kind argument from the bound lambda
    %   is accepted for compatibility but ignored.
    app.redrawModeScatter();
end
