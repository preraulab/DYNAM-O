function onResampleSwitchChanged(app)
    % onResampleSwitchChanged  Enable/disable the Sampling Freq field
    %   to match the Resample Data switch state.
    app.ResampleFsEditField.Enabled          = logical(app.ResampleSwitch.Value);
    app.ResampleFsEditFieldLabel.Enabled     = logical(app.ResampleSwitch.Value);
end
