function tf = hasModeParamData(app, axisKind)
    % hasModeParamData  Return true if any channel in the
    %   currently-loaded SOHist_ChannelInfo_ set has a paramfit
    %   aggregate (.mat preferred, .csv accepted) for the
    %   given axis. axisKind: 'power' | 'phase'.
    tf = false;
    if isempty(app.SOHist_ChannelInfo_), return, end
    root = strtrim(char(app.ResultsBrowserOutputDirField.Value));
    if isempty(root) || ~isfolder(root), return, end
    for ii = 1:numel(app.SOHist_ChannelInfo_)
        ch = app.SOHist_ChannelInfo_(ii).name;
        if app.paramfitAggregatePath(ch, axisKind) ~= ""
            tf = true; return
        end
    end
end
