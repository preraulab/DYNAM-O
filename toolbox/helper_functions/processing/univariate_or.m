%% Perform logical or on 1D vectors regardless of row and column types
% If more of the variables are row, then resultant boolean is row;
% otherwise the output boolean is a column vector

function result = univariate_or(cell_array)
    bool_iscolumn = cellfun(@(x) iscolumn(x), cell_array);
    if mean(bool_iscolumn) >= 0.5
        % more of the variables are column vectors, flip rows to columns
        flip_type = 0;
    else
        % more of the variables are row vectors, flip columns to rows
        flip_type = 1;
    end

    % Flip orientation
    for ii = find(bool_iscolumn == flip_type)
        cell_array{ii} = transpose(cell_array{ii}); 
    end

    % Now perform sequential logical or operations
    result = cell_array{1};

    for ii = 2:length(cell_array)
        result = result | cell_array{ii};
    end
end
