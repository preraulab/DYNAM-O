function tf = is_channel_dir(node)
%IS_CHANNEL_DIR  A directory counts as a channel iff at least one of
%its immediate children is named 'param_basis' or 'SOPHs'.
tf = false;
for ii = 1:numel(node.dirs)
    nm = node.dirs{ii}.name;
    if strcmp(nm,'param_basis') || strcmp(nm,'SOPHs')
        tf = true; return
    end
end
end

