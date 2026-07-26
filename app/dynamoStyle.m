function p = dynamoStyle(theme)
%DYNAMOSTYLE  Single CSSPreset for the DYNAM-O GUI.
%
%   p = dynamoStyle()         % light theme (default)
%   p = dynamoStyle('light')
%   p = dynamoStyle('dark')
%
%   Returns a CSSPreset configured to give the whole DYNAM-O GUI a unified
%   look: one text color across all widgets, neumorphic raised shadow on
%   buttons, carved-in inset shadow on inputs / dropdowns / textareas.
%
%   Usage from the GUI: cache once, reuse everywhere.
%
%       app.AppStyle = dynamoStyle();
%       % then on every widget:
%       CSSuiButton(parent, 'Style', app.AppStyle, 'Text', 'Run', ...);
%       CSSuiEditField(parent, 'Style', app.AppStyle, ...);
%
%   Per-widget appearance is driven by widget-type CSS classes that the
%   CSSuicontrols framework now emits on each component's root element:
%       .cssui-button .cssui-edit .cssui-numeric .cssui-textarea
%       .cssui-dropdown .cssui-listbox .cssui-checkbox .cssui-switch
%       .cssui-radio .cssui-table .cssui-tree .cssui-search
%       .cssui-progressbar .cssui-label
%
%   The :root --color variable (set from p.Color) handles unified text. The
%   p.CSS block uses .cssui-* selectors only where one widget kind needs to
%   diverge from the global defaults (e.g. button background vs input
%   background).

    if nargin < 1 || isempty(theme), theme = 'light'; end
    pal = dynamoPalette(theme);

    p = CSSPreset();

    % Convenience props (compile to :root{ --color, --bg-color, ... }).
    % These propagate into every widget's stylesheet via var(--color, ...).
    p.Color           = pal.text;
    p.BackgroundColor = pal.bgInput;
    p.FontFamily      = '"Segoe UI",system-ui,sans-serif';
    p.FontSize        = '12px';
    p.BorderRadius    = '8px';

    % Buttons use BoxShadow (raised), inputs use InsetShadow (carved-in).
    % Both compile to vars; widget CSS picks whichever it wants.
    p.BoxShadow   = '3px 3px 6px rgba(0,0,0,0.15),-3px -3px 6px rgba(255,255,255,0.9)';
    p.InsetShadow = 'inset 2px 2px 5px #bcbcbc,inset -2px -2px 5px #ffffff';
    p.OuterPadding = '8px';

    % Class-targeted overrides via the new .cssui-* type classes.
    % Order: shared role-class rules first, then widget-type tweaks.
    p.CSS = [ ...
        ... % --- Shared structure (matches shadow_light) ---
        '.css-surface{border:none;transition:box-shadow 0.15s ease,transform 0.15s ease;}' ...
        '.css-label{box-shadow:none!important;background-color:transparent!important;}' ...
        '.css-clickable{cursor:pointer;user-select:none;' ...
        'border:.5px solid rgba(0,0,0,0.05)!important;}' ...
        '.css-clickable:hover{transform:translateY(-2px);' ...
        'box-shadow:4px 4px 8px rgba(0,0,0,0.18),-4px -4px 8px rgba(255,255,255,0.9);}' ...
        '.css-clickable:active{transform:translateY(1px);' ...
        'box-shadow:inset 2px 2px 4px rgba(0,0,0,0.18),inset -2px -2px 4px rgba(255,255,255,0.9);}' ...
        ... % --- Per-widget background tints (uses .cssui-* type classes) ---
        '.cssui-button .css-surface{background-color:' pal.bgButton ';}' ...
        '.cssui-edit .css-surface,.cssui-numeric .css-surface,' ...
        '.cssui-textarea .css-surface,.cssui-dropdown .css-surface,' ...
        '.cssui-listbox .css-surface,.cssui-search .css-surface,' ...
        '.cssui-table .css-surface,.cssui-tree .css-surface' ...
        '{background-color:' pal.bgInput ';}' ...
    ];
end

% =====================================================================

function pal = dynamoPalette(theme)
%DYNAMOPALETTE  Theme-aware color palette for the DYNAM-O GUI.
    switch lower(theme)
        case 'dark'
            pal = struct( ...
                'text',     '#d8e0e8', ...
                'bgInput',  '#1f2933', ...
                'bgButton', '#2f3a45');
        otherwise % 'light'
            pal = struct( ...
                'text',     '#414c57', ...   % matches StatusLabel TextArea
                'bgInput',  '#ffffff', ...
                'bgButton', '#ececec');
    end
end
