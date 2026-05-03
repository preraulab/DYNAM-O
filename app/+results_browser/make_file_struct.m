function fs = make_file_struct(dirPath, fileNames)
%MAKE_FILE_STRUCT  Build a 1×N struct of {name,path} from a name cell array.
n = numel(fileNames);
if n == 0
    fs = struct('name',{},'path',{});
    return
end
paths = cell(1, n);
sep   = filesep;
for ii = 1:n
    paths{ii} = [dirPath sep fileNames{ii}];
end
fs = struct('name', fileNames, 'path', paths);
end

