function syncY(sourceAx, targetAx, state, field)
if state.(field), return; end
state.(field) = true;
set(targetAx, 'YLim', get(sourceAx, 'YLim'));
state.(field) = false;
end