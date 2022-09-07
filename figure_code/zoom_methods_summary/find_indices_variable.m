function[inds_var] = find_indices_variable(variable_name,matr_names,matr_fields)
% function to find the start and index of the columns corresponding to a
% particular variable

% find the index of the variable name in matr_names
ind_var_matr_names=find(strcmp(variable_name,matr_names));

% cumsum the matr_fields to the end index of each of the variables in the
% columns of peaks_matr. The start index will be the previous value in the
% cumsum array+1
matr_fields_cumsum=cumsum(matr_fields);

if ((ind_var_matr_names)~=1)
    inds_var=[matr_fields_cumsum(ind_var_matr_names-1)+1,...
        matr_fields_cumsum(ind_var_matr_names)];
else
    inds_var=[1,1];
end
end