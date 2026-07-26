function refreshChannelTooltips(app)
    % refreshChannelTooltips  Refresh the Channel(s) and
    % Reference(s) field/label tooltips to reflect current
    % state. Called from finalizeUI (initial empty state) and
    % from the composer's doOk after committing changes.
    %
    % Empty:     "No channels yet. Click Select Channels to add."
    % Populated: "Channels (N): a, b, c. Click Select Channels
    %             to add or remove."
    if isempty(app.ChannelList)
        chanTip = 'No output channels yet. Click Select Channels to add channels.';
    else
        chanTip = sprintf('Output channels (%d): %s. Click Select Channels to add or remove.', ...
            numel(app.ChannelList), strjoin(app.ChannelList, ', '));
    end
    if isempty(app.ReferenceList)
        refTip = 'No references defined. References are optional — click Select Channels to add one.';
    else
        refTip = sprintf('References (%d): %s. Click Select Channels to add or remove.', ...
            numel(app.ReferenceList), strjoin(app.ReferenceList, ', '));
    end
    app.ChannelEditField.HTMLComponent.Tooltip      = chanTip;
    app.ChannelEditFieldLabel.HTMLComponent.Tooltip = chanTip;
    app.ReferenceEditField.HTMLComponent.Tooltip    = refTip;
    app.ReferenceLabel.HTMLComponent.Tooltip        = refTip;
end
