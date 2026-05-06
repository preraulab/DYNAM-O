function updateChannelInput(app)
    % updateChannelInput  Parse the channel edit field into a cell array of names.
    %
    %   Splits the comma-separated string in ChannelEditField and stores
    %   the result in app.ChannelList. Commas inside parentheses
    %   ('mean(A1, A2)') and inside '$LABEL$' escape regions are
    %   ignored — only top-level commas separate channel specs.

    app.ChannelList = app.splitTopLevelCommas(app.ChannelEditField.Value);
end
