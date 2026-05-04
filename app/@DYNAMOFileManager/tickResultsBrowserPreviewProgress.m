function tickResultsBrowserPreviewProgress(app, k)
    % tickResultsBrowserPreviewProgress  Advance the current
    %   SmoothProgressBar to iteration k. Silently no-ops if the
    %   bar was destroyed (e.g. by a file preview render that
    %   cleared the preview body) — the next setup call will
    %   rebuild on the next stage transition.
    pb = app.PreviewProgressBar_;
    if isempty(pb) || ~isvalid(pb), return, end
    try
        pb.updateIteration(k);
    catch
        % Bar may have been completed externally; ignore.
    end
end
