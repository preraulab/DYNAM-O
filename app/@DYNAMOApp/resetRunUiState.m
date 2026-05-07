function resetRunUiState(app)
    % resetRunUiState  Restore the RUN button to its idle state
    % (play-triangle icon, label "RUN"). Called on completion,
    % stop, or error of a batch. Clears the running-state CSS
    % override so future Enabled=false transitions get the
    % normal greyed-out visual again.
    app.RunBatchButton.Icon = '<path d="M8 5v14l11-7z"/>';
    app.RunBatchButton.Text = 'RUN';
    app.RunBatchButton.CSS  = '';
    drawnow;
end
