function moveListItems(app, listType, direction)
    % moveListItems  Shift selected items up or down in a file list.
    %
    %   moveListItems(app, listType, direction)
    %
    %   Inputs:
    %     listType  – 'data' or 'staging'
    %     direction – 'up' or 'down'
    %
    %   The function is order-preserving: contiguous blocks move as a unit.

    % Resolve the target list and list-box based on type
    switch listType
        case 'data',    currentList = app.DataList;    lb = app.DataListBox;
        case 'staging', currentList = app.StagingList; lb = app.StagingListBox;
    end

    selected = lb.Value;
    if isempty(selected), return; end

    % Find indices of selected items in the current list
    idx     = find(ismember(currentList, selected));
    newList = currentList;

    if strcmp(direction, 'up') && idx(1) > 1
        % Shift each selected item one position toward the start
        for i = 1:length(idx)
            tmp = newList{idx(i)};
            newList{idx(i)}   = newList{idx(i)-1};
            newList{idx(i)-1} = tmp;
        end
    elseif strcmp(direction, 'down') && idx(end) < length(newList)
        % Shift each selected item one position toward the end (iterate in reverse)
        for i = length(idx):-1:1
            tmp = newList{idx(i)};
            newList{idx(i)}   = newList{idx(i)+1};
            newList{idx(i)+1} = tmp;
        end
    end

    % Write back and refresh the list-box, restoring the selection
    switch listType
        case 'data'
            app.DataList = newList;
            updateDataListBox(app);
            lb.Value = selected;
        case 'staging'
            app.StagingList = newList;
            updateStagingListBox(app);
            lb.Value = selected;
    end
end
