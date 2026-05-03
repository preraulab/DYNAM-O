function s = node_label(name, val)
sz = size(val);
szStr = strjoin(arrayfun(@(d) sprintf('%d',d), sz, 'UniformOutput', false), '×');
s = sprintf('%s  (%s %s)', name, class(val), szStr);
end

