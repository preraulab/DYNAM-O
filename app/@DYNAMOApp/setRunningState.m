function setRunningState(app)
    % setRunningState  Swap the RUN button into its "running" state:
    % an animated SVG bar-graph icon and the label "RUNNING".
    % Also overrides the default Enabled=false visual (50%
    % opacity fade) so the button reads as actively running
    % rather than greyed-out unavailable: full-opacity light
    % green background, full-strength text, no shadows. The
    % button is still pointer-events:none from the .css-
    % disabled rule, so it remains untouchable.
    app.RunBatchButton.Icon = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 135 140" fill="currentColor"><rect y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="30" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="60" width="15" height="140" rx="6"><animate attributeName="height" begin="0s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="90" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.25s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.25s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect><rect x="120" y="10" width="15" height="120" rx="6"><animate attributeName="height" begin="0.5s" dur="1s" values="120;110;100;90;80;70;60;50;40;140;120" calcMode="linear" repeatCount="indefinite"/><animate attributeName="y" begin="0.5s" dur="1s" values="10;15;20;25;30;35;40;45;50;0;10" calcMode="linear" repeatCount="indefinite"/></rect></svg>';
    app.RunBatchButton.Text = 'RUNNING';
    app.RunBatchButton.CSS = [ ...
        '.css-control{background-color:#ABFFCD !important;}' ...
        '.css-disabled{opacity:1 !important;}' ...
        '.css-disabled *{opacity:1 !important;color:inherit !important;' ...
        'text-shadow:none !important;box-shadow:none !important;' ...
        'filter:none !important;}'];
    drawnow;
end
