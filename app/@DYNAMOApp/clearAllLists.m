function clearAllLists(app)
    % clearAllLists  Remove all entries from both the data and staging lists.
    %
    %   clearAllLists(app)

    app.DataList    = {};
    app.StagingList = {};
    updateDataListBox(app);
    updateStagingListBox(app);
end
