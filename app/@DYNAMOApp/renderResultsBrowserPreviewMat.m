function renderResultsBrowserPreviewMat(app, p)
    % renderResultsBrowserPreviewMat  Top-level dispatcher for
    % .mat preview. Inspects top-level variables via whos to
    % avoid loading large files, then routes to a smart-case
    % renderer (SOPHs, paramfit, splinefit, auxiliary, stats,
    % aggregate) or falls back to a generic struct browser.
    delete(app.ResultsBrowserPreviewBody.Children);
    try
        info = whos('-file', p);
    catch ME
        app.renderResultsBrowserPreviewMessage( ...
            sprintf('Could not read MAT file:\n%s', ME.message));
        return
    end
    if isempty(info)
        app.renderResultsBrowserPreviewMessage('Empty .mat file.');
        return
    end
    names = {info.name};

    % --- Smart cases (peek var names, then load only what's needed) ---
    try
        % SOPHs MAT comes in two layouts:
        %   - legacy nested:  one 'SOPHs' struct variable
        %   - new flat:       top-level vars (SOpower_mat, freq_bins, ...)
        % Both route to previewMatSOPHs, which handles either shape.
        is_flat_sophs = (any(strcmp(names, 'SOpower_mat')) || ...
                         any(strcmp(names, 'SOphase_mat'))) && ...
                        ~any(strcmp(names, 'aggregate'));
        if any(strcmp(names, 'SOPHs')) || is_flat_sophs
            app.previewMatSOPHs(p);                    return
        end
        if any(strcmp(names, 'SOpower_paramfit')) || ...
           any(strcmp(names, 'SOphase_paramfit'))
            app.previewMatParamfit(p, names);          return
        end
        if any(strcmp(names, 'SOpower_splinefit')) || ...
           any(strcmp(names, 'SOphase_splinefit'))
            app.previewMatSplinefit(p, names);         return
        end
        if any(strcmp(names, 'auxiliary_data'))
            app.previewMatAuxiliary(p);                return
        end
        if any(strcmp(names, 'stats_table'))
            app.previewMatStatsTable(p);               return
        end
        if any(strcmp(names, 'aggregate'))
            app.previewMatAggregate(p);                return
        end
    catch ME
        app.renderResultsBrowserPreviewMessage( ...
            sprintf('Smart-case render failed:\n%s', ME.message));
        return
    end

    % --- Generic fallback ---
    app.renderResultsBrowserPreviewMatGeneric(p, info);
end
