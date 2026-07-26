function onModeScatterDropDownChanged(app, ~)
    % onModeScatterDropDownChanged  Shared ValueChangedFcn for
    %   all eight Mode Scatter dropdowns (Power and Phase
    %   X/Y/Size/Color). Channel selection is unchanged here, so
    %   route through the in-place updater (no layout rebuild).
    %   The axis-kind argument from the bound lambda is accepted
    %   for compatibility but ignored — the updater walks both.
    app.updateModeScatterData();
end
