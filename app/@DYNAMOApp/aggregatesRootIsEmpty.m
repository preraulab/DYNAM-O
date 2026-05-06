function tf = aggregatesRootIsEmpty(~, aggregatesRoot)
    % aggregatesRootIsEmpty  Return true if aggregates/ exists
    %   but contains no regular files in any subtree. Cheap
    %   recursive walk; bails out as soon as the first file
    %   is found.
    tf = true;
    if ~isfolder(aggregatesRoot), return, end
    stack = {aggregatesRoot};
    while ~isempty(stack)
        d = stack{end}; stack(end) = [];
        entries = dir(d);
        for ii = 1:numel(entries)
            e = entries(ii);
            if any(strcmp(e.name, {'.','..'})), continue, end
            if e.isdir
                stack{end+1} = fullfile(d, e.name); %#ok<AGROW>
            else
                tf = false; return
            end
        end
    end
end
