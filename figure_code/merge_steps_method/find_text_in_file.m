function [idx_text] = find_text_in_file(inputfile,txt)

fid = fopen(inputfile, 'rt');
% read the entire file, if not too big
s = textscan(fid, '%s', 'delimiter', '\n');
% search for your Region:
idx1 = strfind(s{1,1},txt);
idx_text=find(cellfun(@(x)isequal(x,1),idx1));
fclose(fid);

end