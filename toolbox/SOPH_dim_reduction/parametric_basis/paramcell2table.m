%PARAMCELL2TABLE Combine cell array of matrices into a table with subject IDs
%
%   Usage:
%       param_table = paramcell2table(subjIDs, ages, data_cells)
%
%   Input:
%       subjIDs: n x 1 vector - vector of subject IDs -- required
%       ages: n x 1 vector - vector of subject ages -- required
%       data_cells: n x 1 cell array - each cell is either empty or contains a matrix -- required
%
%   Output:
%       param_table: table - combined table with subject IDs added as the first column and appropriate column names
%
%   Example:
%   In this example, we create some sample data and combine it into a table.
%       subjIDs = [1; 2; 3];
%       ages = [10; 20; 30];
%       data_cells = {rand(3,6); []; rand(2,6)};
%       combined_table = paramcell2table(subjIDs, ages, data_cells);
%       disp(combined_table);
%
%    Copyright 2024 Prerau Laboratory - sleepEEG.org
%*********************************************
function param_table = paramcell2table(subjIDs, ages, data_cells)

    % Calculate total number of rows needed
    total_rows = sum(cellfun(@(x) size(x, 1), data_cells));

    % Check if there are any non-empty cells
    if total_rows == 0
        param_table = table(); % Return an empty table if all cells are empty
        return;
    end

    % Determine the number of columns in the matrices (assuming all non-empty matrices have the same number of columns)
    num_cols = size(data_cells{find(~cellfun('isempty', data_cells), 1)}, 2) + 2; % Add 2 for the subj_ID and age columns

    % Preallocate combined_data array
    combined_data = zeros(total_rows, num_cols);

    % Initialize a row index for combined_data
    current_row = 1;

    % Loop over each subject
    for i = 1:length(subjIDs)
        if ~isempty(data_cells{i})
            % Number of rows in the current matrix
            num_rows = size(data_cells{i}, 1);
            % Add the subject ID as the first column
            combined_data(current_row:current_row+num_rows-1, :) = [repmat(subjIDs(i), num_rows, 1), repmat(ages(i), num_rows, 1), data_cells{i}];
            % Update the current row index
            current_row = current_row + num_rows;
        end
    end

    % Convert the combined data array to a table
    param_table = array2table(combined_data, 'VariableNames', {'Subj_ID', 'Age', 'Amplitude', 'Frequency', 'STDfreq', 'Feature', 'STDfeat', 'Theta'});
end
