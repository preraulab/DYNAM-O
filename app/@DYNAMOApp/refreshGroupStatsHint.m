function refreshGroupStatsHint(app)
    % refreshGroupStatsHint  Update the explanatory line at the top of
    %   the Group Stats inner tab so the user knows what's missing
    %   before the buttons will produce anything useful. permtest /
    %   gpermtest are two-sample tests, so we need exactly two
    %   selected values in the Group filter listbox.
    if isempty(app.GroupStatsHintLabel) || ~isvalid(app.GroupStatsHintLabel)
        return
    end

    [ok, msg] = app.groupStatsState();
    app.GroupStatsHintLabel.Text = msg;
    if ok
        app.GroupStatsHintLabel.FontColor = [0.10 0.45 0.10];
    else
        app.GroupStatsHintLabel.FontColor = [0.55 0.10 0.10];
    end
end
