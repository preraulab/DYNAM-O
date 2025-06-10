%FIGDESIGN  Simple, interactive design tool for figure and axes. Can format grids of axes,
%           as well as merge existing axes.
%
%   Usage:
%       axis_handles=figdesign(num_rows, num_cols, options)
%       axis_handles=figdesign(fig_handle, num_rows, num_cols, options)
%       axis_handles=figdesign() %Run with no parameters for design mode
%       axis_handles=figdesign('demo') %Run demo
%
%   Input:
%   num_rows: the number of rows in the subplot
%   num_cols: the number of columns in the subplot
%   fig_handle: handle to parent figure
%
%   Options:
%   iteract: a boolean, which enables/disables grid interaction window (default: false).
%            Closing the interaction window actives interactive merging.
%            menu option on main figure.
%
%            To get new figure handles after interactive mergine, use:
%               axes_handles=figdesign('handles');
%   margins: a vector of margin size defined in normalized units as [top bottom left right column row]
%            (default: [.1 .05 .08 .05 .08 .08])
%   merge: an array or cell array, with indices of axes to merge
%   numberaxes: logical, titles each axis with the axis number (default: false)
%   <figure options>: list of name-value pairs of valid options for figure
%   class. Units are forced to be normalized
%
%   Output:
%   axis_handles: 1x(num_rows*numcols) vector of axis handles
%
%   TO RUN DESIGN MODE:
%       ax = figdesign();
%
%   TO RUN DEMO:
%       figdesign('demo');
%
%   Examples:
%         EXAMPLE 1:
%             %Simple instantiation
%             figure
%             ax=figdesign(2,2);
%             for i=1:length(ax)
%                 plot(ax(i), randn(1,1000));
%             end
%             linkaxes(ax,'x');
%
%         EXAMPLE 2:
%             %Define custom margins
%             top=.05;
%             bottom=.05;
%             left=.08;
%             right=.05;
%             column=.2;
%             row=.3;
%
%             %Create subplot
%             figdesign(2,2,'margins',[top bottom left right column row]);
%
%         EXAMPLE 3:
%             %Define specific page size and orient
%             figure
%             figdesign(2,3,'type','usletter','orient','landscape');
%
%         EXAMPLE 4:
%             %Merge axes
%             figure
%             figdesign(4,4,'type','usletter','orient','portrait','merge',{1:3,[5 6 9 10],[4 8 12 16], [7 11],[14 15]});
%
%         EXAMPLE 5:
%             %Interactive merge figures
%             figure
%             figdesign(3,3,'type','usletter','orient','portrait');
%             msgbox('Under the figure menu, select FigDesign>Merge. Single click on axes to merge. Double click on the last axis to complete merger.');
%
%         EXAMPLE 6:
%             %Interactive adjust page margins
%             figure
%             figdesign(3,3,'type','usletter','orient','portrait','units','inches','margins',[.5 .5 1 1 .5],'interact',1);
%             msgbox('Move sliders to adjust axes parameters. Type in the edit boxes to enter specific numerical values. When the adjustment window is closed, interactive figure merging is enabled on the main figure.');
%
%             %Call with handles operator to get new axes handles
%             axs=figdesign('handles');
%             linkaxes(axs,'x');
%
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

function axis_handles=figdesign(varargin)
%Run demo
if (nargin==1 && strcmpi(varargin{1},'demo'))
    demo();
    return;
end

%Run in design mode
if nargin == 0
    out = make_layout_fig;
    params = out{1};
    fig = out{2};
    delete(fig);

    figure
    axis_handles=figdesign(params.row, params.col, 'orient',params.orientation,'interact',true);
    return;
end

if isa(varargin{1},'matlab.ui.Figure')
    mainfig_h = varargin{1};
    varargin = varargin(2:end);
else
    mainfig_h = gcf;
end

%Parse input options
p=inputParser;
p.addOptional('numrows',@(x)validateattributes(x,{'numeric'},{'positive','integer'}));
p.addOptional('numcols',@(x)validateattributes(x,{'numeric'},{'positive','integer'}));
p.addOptional('margins',[.05 .05 .08 .05 .08 .08],@(x)validateattributes(x,{'numeric','1d','vector'},{'positive','<=',1}));
p.addOptional('interact',false,@logical);
p.addOptional('merge','');
p.addOptional('orient','portrait', @(x)any(validatestring(x,{'portrait','landscape','full'})));
p.addOptional('type', 'usletter');
p.addOptional('numberaxes', false);
p.KeepUnmatched = true;

p.parse(varargin{:});

num_rows = p.Results.numrows;
num_cols = p.Results.numcols;
margins=p.Results.margins;
interact=logical(p.Results.interact);
merge=p.Results.merge;
orientation=p.Results.orient;
paper_type=p.Results.type;
numberaxes = p.Results.numberaxes;

%Check if full sized paper is selected
if strcmpi(orientation,'full')
    orientation = 'landscape';
    full_on = true;
else
    full_on = false;
end

%Sets default to portrait letter
set(mainfig_h,'paperpositionmode','auto');
set(mainfig_h,'units','normalized','paperorientation',orientation,'papertype',paper_type,'color','w');
set(mainfig_h,'units','inches','position',[0 0 get(mainfig_h,'papersize')],'color','w');
set(mainfig_h,'units','normalized');

if full_on
    set(mainfig_h,'position',[0 0 1 1]);
end

%Keep track of interactively merged axes
mainfig_h.UserData.merged = {};
mainfig_h.UserData.params.num_rows = num_rows;
mainfig_h.UserData.params.num_cols = num_cols;
mainfig_h.UserData.params.margins = margins;
mainfig_h.UserData.params.orient = orient;
mainfig_h.UserData.params.type = paper_type;
units = 'normalized';

%Recreate varargin removing the x/y axis location name pairs
varargin = cat(2,fieldnames(p.Unmatched),struct2cell(p.Unmatched));
varargin = reshape(varargin',1, numel(varargin));

if ~isempty(varargin)
    set(mainfig_h,varargin{:});
end

if length(margins)~= 5 && length(margins) ~=6
    error('Margins must have 5 or 6 elements');
end

if length(margins) == 5
    margins(6) = margins(5);
end

%Set up axesaxis_handles
axis_handles=create_axes(mainfig_h, margins(1),margins(2),margins(3),margins(4), margins(5), margins(6), num_cols, num_rows, units);

%Disable interaction for merged
if ~isempty(merge)
    if interact
        disp('Interaction disabled for merged axes');
        interact=false;
    end

    if ~iscell(merge)
        merge_axes(axis_handles(merge), mainfig_h);
    else
        for i=1:length(merge)
            new_axis = merge_axes(axis_handles(merge{i}), mainfig_h);
            axis_handles(end+1) = new_axis; %#ok<AGROW>
        end
    end

    %Keep only active axes
    axis_handles= axis_handles(ishandle(axis_handles));
    apos=get(axis_handles,'position');
    apos=reshape([apos{:}],4,numel([apos{:}])/4)';

    %Sort by height
    [s1,inds]=sortrows(apos,2);
    levels=unique(s1(:,2));

    %Sort left before right
    for i=1:length(levels)
        ind1=find(s1(:,2)==levels(i));
        [~,ind2]=sort(s1(ind1,1),'descend');
        inds(ind1)=inds(ind1(ind2));
    end

    axis_handles=axis_handles(flipud(inds));
end

%Set up interaction
if interact
    run_interaction(mainfig_h,margins, axis_handles, num_rows, num_cols, units);
else
    c = get(mainfig_h,'children');
    menu_inds = arrayfun(@(x)strcmpi(class(x),'matlab.ui.container.Menu'),c);

    if ~any(menu_inds) || ~any(strcmpi({c(menu_inds).Text},'FigDesign'))
        %If not adjusting, add the merge menu to the main figure toolbar
        f = uimenu('Label','FigDesign');
        uimenu(f,'Label','Merge...','Callback',@(src,evnt)merge_axes([], mainfig_h));
        uimenu(f,'Label','Generate call...','Callback',@(src,evnt)generate_call(mainfig_h));
    end
end

% Add numbers to axes for easy identification
if numberaxes
    for ii = 1:length(axis_handles)
        title(axis_handles(ii), ['Axis ' num2str(ii)]);
    end
end

%*****************************************************
%             CREATE INTERACTIVE AXES
%*****************************************************
function run_interaction(mainfig_h, margins, axis_handles, num_rows, num_cols, units)
%Set range
hmax=1;
wmax=1;

%Create the position interaction figure
marginfig_h = figure('Position',[250 250 350 330],...
    'MenuBar','none','NumberTitle','off','color','w',...
    'Name','Adjust Subplots');

set(marginfig_h,'closerequestfcn',@(src,evnt)close_interactive(marginfig_h, mainfig_h))

%Create the sliders
topslider_h = uicontrol(marginfig_h,'units','pixel','Style','slider',...
    'Max',hmax,'Min',1e-100,'Value',margins(1),...
    'SliderStep',[0.05 0.2],...
    'Position',[25 275 300 20]);
bottomslider_h = uicontrol(marginfig_h,'units','pixel','Style','slider',...
    'Max',hmax,'Min',1e-100,'Value',margins(2),...
    'SliderStep',[0.05 0.2],...
    'Position',[25 225 300 20]);
leftslider_h = uicontrol(marginfig_h,'units','pixel','Style','slider',...
    'Max',wmax,'Min',1e-100,'Value',margins(3),...
    'SliderStep',[0.05 0.2],...
    'Position',[25 175 300 20]);
rightslider_h = uicontrol(marginfig_h,'units','pixel','Style','slider',...
    'Max',wmax,'Min',1e-100,'Value',margins(4),...
    'SliderStep',[0.05 0.2],...
    'Position',[25 125 300 20]);
col_midslider_h = uicontrol(marginfig_h,'units','pixel','Style','slider',...
    'Max',max([wmax hmax]),'Min',1e-100,'Value',margins(5),...
    'SliderStep',[0.05 0.2],...
    'Position',[25 75 300 20]);
row_midslider_h = uicontrol(marginfig_h,'units','pixel','Style','slider',...
    'Max',max([wmax hmax]),'Min',1e-100,'Value',margins(5),...
    'SliderStep',[0.05 0.2],...
    'Position',[25 25 300 20]);

%Array of all slider handles
sliders_h=[topslider_h bottomslider_h leftslider_h rightslider_h col_midslider_h row_midslider_h];

%Create descriptor texts for the sliders
uicontrol(marginfig_h,'units','pixel','Style','text','string','Top Margin','Position',[25 295 100 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','left');
uicontrol(marginfig_h,'units','pixel','Style','text','string','Bottom Margin','Position',[25 245 100 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','left');
uicontrol(marginfig_h,'units','pixel','Style','text','string','Left Margin','Position',[25 195 100 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','left');
uicontrol(marginfig_h,'units','pixel','Style','text','string','Right Margin','Position',[25 145 100 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','left');
uicontrol(marginfig_h,'units','pixel','Style','text','string','Column Margins','Position',[25 95 100 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','left');
uicontrol(marginfig_h,'units','pixel','Style','text','string','Row Margins','Position',[25 45 100 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','left');

%Create the edit boxes for manual entry of parameter values
topedit_h=uicontrol(marginfig_h,'units','pixel','Style','edit','string',num2str(margins(1)),'Position',[120 297 70 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','right');
bottomedit_h=uicontrol(marginfig_h,'units','pixel','Style','edit','string',num2str(margins(2)),'Position',[120 247 70 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','right');
leftedit_h=uicontrol(marginfig_h,'units','pixel','Style','edit','string',num2str(margins(3)),'Position',[120 197 70 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','right');
rightedit_h=uicontrol(marginfig_h,'units','pixel','Style','edit','string',num2str(margins(4)),'Position',[120 147 70 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','right');
col_midedit_h=uicontrol(marginfig_h,'units','pixel','Style','edit','string',num2str(margins(5)),'Position',[120 97 70 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','right');
row_midedit_h=uicontrol(marginfig_h,'units','pixel','Style','edit','string',num2str(margins(6)),'Position',[120 47 70 20],'backgroundcolor',get(mainfig_h,'color'),'horizontalalign','right');

%Array of all edit box handles
editboxes_h=[topedit_h bottomedit_h leftedit_h rightedit_h col_midedit_h row_midedit_h];

%Set the edit box callbacks
set(topedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,1, mainfig_h, num_cols, num_rows, units));
set(bottomedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,2, mainfig_h, num_cols, num_rows, units));
set(leftedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,3, mainfig_h, num_cols, num_rows, units));
set(rightedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,4, mainfig_h, num_cols, num_rows, units));
set(col_midedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,5, mainfig_h, num_cols, num_rows, units));
set(row_midedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,6, mainfig_h, num_cols, num_rows, units));

%Set continuous callbaxs for the sliders
addlistener(topslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,1, mainfig_h, num_cols, num_rows, units));
addlistener(bottomslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,2, mainfig_h, num_cols, num_rows, units));
addlistener(leftslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,3, mainfig_h, num_cols, num_rows, units));
addlistener(rightslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,4, mainfig_h, num_cols, num_rows, units));
addlistener(col_midslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,5, mainfig_h, num_cols, num_rows, units));
addlistener(row_midslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,6, mainfig_h, num_cols, num_rows, units));

%Fix the main figure so that it closes the adjustment window when
%deleted
set(mainfig_h,'closerequestfcn',@(src,evnt)close_all(mainfig_h, marginfig_h));

%*****************************************************
%             UPDATE AXIS GRID FROM SLIDER
%*****************************************************
function slider_update(axs, slider_h, edit_h, value, mainfig_h, num_cols, num_rows, units)
%Get the max and min figure bounds
if ~strcmpi(units,'normalized')
    pos=get(mainfig_h,'position');
    wmax=pos(3);
    hmax=pos(4);
else
    hmax=1;
    wmax=1;
end

%Get margins from the slider values
margins=cell2mat(get(slider_h,'value'));
margins(value)=get(slider_h(value),'value');

top_margin=margins(1);
bottom_margin=margins(2);
left_margin=margins(3);
right_margin=margins(4);

if length(margins) == 5
    midh_margin=margins(5);
    midv_margin=margins(5);
elseif length(margins) ==6
    midh_margin=margins(5);
    midv_margin=margins(6);
else
    error('Margins must have 5 or 6 elements');
end


%Set the edit boxes to match the slider values
set(edit_h(value),'string',num2str(margins(value)));

num_axes=length(axs); %Number of axes

%Compute the height and width for the axes
ax_width=(wmax-left_margin-right_margin-midh_margin*(num_cols-1))/num_cols;
ax_height=(hmax-top_margin-bottom_margin-midv_margin*(num_rows-1))/num_rows;

%Loop through each axis and define properties
ax_number=1; %Counter
for r=1:num_rows
    for c=1:num_cols
        if ax_number<=num_axes
            %Compute left and bottom coordinates
            left=left_margin+midh_margin*(c-1)+ax_width*(c-1);
            bottom=hmax-top_margin-midv_margin*(r-1)-ax_height*r;

            %Set new axis position
            set(axs(ax_number),'position',max([left bottom ax_width ax_height],1e-100));

            ax_number=ax_number+1;
        end
    end
end

%Update margin parameters
mainfig_h.UserData.params.margins = margins';

%*****************************************************
%                CREATE GRID OF AXES
%*****************************************************
function axis_handles=create_axes(mainfig_h, top_margin, bottom_margin, left_margin, right_margin, midh_margin, midv_margin, num_cols, num_rows, units)
%Get the max and min figure bounds
hmax=1;
wmax=1;

%Compute the height and width for the axes
ax_width=(wmax-left_margin-right_margin-midh_margin*(num_cols-1))/num_cols;
ax_height=(hmax-top_margin-bottom_margin-midv_margin*(num_rows-1))/num_rows;

%Set up output vector
num_axes=num_cols*num_rows;
axis_handles=matlab.graphics.axis.Axes.empty(num_axes,0);

%Loop through each axis and define properties
ax_number=1; %Counter
for r=1:num_rows
    for c=1:num_cols
        if ax_number<=num_axes
            %Compute left and bottom coordinates
            left=left_margin+midh_margin*(c-1)+ax_width*(c-1);
            bottom=hmax-top_margin-midv_margin*(r-1)-ax_height*r;

            %Create new axis
            axis_handles(ax_number)=axes('parent',mainfig_h,'units',units,'position',[left bottom ax_width ax_height],'Tag',num2str(ax_number));
            axis_handles(ax_number).UserData.Parents = [];

            %Update counter
            ax_number=ax_number+1;
        end
    end
end

%*****************************************************
%     UPDATE SLIDERS AND FIGURE WHEN TEXT IS EDITED
%*****************************************************
function edit_update(axs, slider_h, edit_h, value, mainfig_h_h, num_cols, num_rows, units)
%Get the new value from the edited text box
newval=get(edit_h(value),'string');

%Set the slider to the appropriate value
set(slider_h(value),'value',str2double(newval));
slider_update(axs, slider_h, edit_h, value, mainfig_h_h, num_cols, num_rows,units);

%*****************************************************
%             MERGE SELECTED AXES
%*****************************************************
function new_axis = merge_axes(merger_axes,mainfig_h)
%Interactive selection of merger axes
if nargin==1 || isempty(merger_axes)
    %If interactive selection is on
    disp('Click to select axes. Double click on final axis to merge...');
    mainfig_h = gcf;
    %Create log of axes clicked
    handle=guidata(mainfig_h);
    handle.axes=[];
    guidata(mainfig_h,handle);

    %Get the axes in the figure
    all_axes=findobj(mainfig_h,'type','axes');
    %Allow them to accept clicks
    set(all_axes,'buttondownfcn',{@select_axes,mainfig_h});

    %Pause until double click
    uiwait(mainfig_h);

    %Grab axes to be merged
    handle=guidata(mainfig_h);
    merger_axes=handle.axes;
end

%Get axes units
units=get(merger_axes(1),'units');

%Warning check for number of axes
if isscalar(merger_axes)
    warning('Only one axis selected. No merger possible.');
    return;
end

%Error check for invalid axes
if any(~ishandle(merger_axes))
    error('Invalid axis for merger');
end

%Get the existing axes position
pos=cell2mat(get(merger_axes,'position'));

%Find new width
[~, imin]=min(pos(:,1));
[~, imax]=max(pos(:,1));
new_width=pos(imax,1)+pos(imax,3)-pos(imin,1);

%Find new height
[~, imin]=min(pos(:,2));
[~, imax]=max(pos(:,2));
new_height=pos(imax,2)+pos(imax,4)-pos(imin,2);

%Get new position
new_pos=[min(pos(:,1:2)) new_width new_height];

%Save the indices of the merged figures
%Get the axis numbers of the figures that we are merging
merged_axes_nums = unique(cellfun(@str2double,{merger_axes.Tag}));
merged_axes_nums(isnan(merged_axes_nums)) = [];

%See if any of the axes have previously been merged
parents = cell2mat(cellfun(@(x)x.Parents,{merger_axes.UserData},'UniformOutput',false));

%Remove any pre-merged elements
if ~isempty(parents)
    child_inds = cellfun(@(x)any(ismember(x,parents)), mainfig_h.UserData.merged);

    if any(child_inds)
        mainfig_h.UserData.merged(child_inds) = [];
    end
end

%Combine all merged axes and parents
merged_axes_nums= unique([merged_axes_nums parents]);

%Add to the user data
mainfig_h.UserData.merged{end+1} = merged_axes_nums;

%Delete original axes and create new
delete(merger_axes)
new_axis=axes('units',units,'position',new_pos);
new_axis.UserData.Parents = merged_axes_nums;

%Put new axis below other axes
uistack(new_axis,'bottom');

%*****************************************************
%        HELPER FUNCTION FOR AXIS SELECTION
%*****************************************************
function select_axes(axs,~,mainfig_h)
%Add selected axis to data
handle=guidata(mainfig_h);
handle.axes=unique([handle.axes axs]);
guidata(mainfig_h,handle);

%Continue merging
if strcmpi(get(mainfig_h,'selectiontype'),'open')
    uiresume(mainfig_h);
end

%*****************************************************
%       CLOSE INTERACTIVE_FIGURE 
%*****************************************************
function close_interactive(layoutfig_h, mainfig_h)
delete(layoutfig_h);

% Retrieve the figure handle
figure(mainfig_h)
f = uimenu('Label','FigDesign');
uimenu(f,'Label','Merge...','Callback',@(src,evnt)merge_axes([], mainfig_h));
uimenu(f,'Label','Generate call...','Callback',@(src,evnt)generate_call(mainfig_h));

%*****************************************************
%               PROPERLY CLOSE WINDOWS
%*****************************************************
function close_all(mainfig_h_h, posfig_h)
delete(mainfig_h_h)
if ishandle(posfig_h)
    delete(posfig_h)
end

%*****************************************************
%                       RUN DEMO
%*****************************************************
function demo
clc;
close all;

msgbox('This is a demo of the figdesign function. Close this window and press any key to begin, and to cycle through subsequent examples. Example will appear on the main command window.','Demo of figdesign()');
disp('Press any key to begin...');
pause;
close all;
%%
clc;
disp('%*****************************************************');
disp('%            Create a simple grid of axes');
disp('%*****************************************************');
disp(' ');
disp('figure;');
disp('%Create grid of axes');
disp('figdesign(2,2);');
disp(' ');

figure;
figdesign(2,2);
disp('Press any key to continue...');
pause;
close all;
clc
%%
clc;
disp('%*****************************************************');
disp('%  Create a grid of axes with custom margin sizes');
disp('%*****************************************************');
disp(' ');
disp('figure;');
disp('%Define custom margins');
disp('top=.1;');
disp('bottom=.1;');
disp('left=.1;');
disp('right=.1;');
disp('column=.2;');
disp('row=.3;');
disp(' ');
disp('%Create grid of axes with custom margins');
disp('figdesign(2,2,''margins'',[top bottom left right column row]);');
disp(' ');

figure;
%Define custom margins
top=.1;
bottom=.1;
left=.1;
right=.1;
column=.2;
row=.3;

%Create subplot
figdesign(2,2,[top bottom left right column row]);
disp('Press any key to continue...');
pause;
close all;

%%
clc;
disp('%*****************************************************');
disp('%  Define specific page size and orientation');
disp('%*****************************************************');
disp(' ');
disp('figure');
disp('figdesign(2,3,''type'',''usletter'',''orient'',''landscape'');');
disp(' ');

figure
figdesign(2,3,'type','usletter','orient','landscape');
disp('Press any key to continue...');
pause;
close all;

%%
clc
disp('%*****************************************************');
disp('%      Define axes to merge using a cell array');
disp('%*****************************************************');
disp(' ');
disp('figure');
disp('figdesign(4,4,''type'',''usletter'',''orient'',''portrait'',''merge'',{1:3,[5 6 9 10],[4 8 12 16], [7 11],[14 15]});');

%Merge axes
figure
figdesign(4,4,'type','usletter','orient','portrait','merge',{1:3,[5 6 9 10],[4 8 12 16], [7 11],[14 15]});
disp('Press any key to continue...');
pause;
close all;

%%
clc
disp('%*****************************************************');
disp('%      Using the interactive merging feature');
disp('%*****************************************************');
disp(' ');
disp('%To merge axes, select FigDesign>Merge in the main figure menu bar. Left click on axes to merge, double-clicking on the last axis to complete merger.');
disp('%This process may repeated multiple times by reselecting FigDesign>Merge. Give it a try :)');
disp(' ');
disp('figure');
disp('figdesign(3,3,''type'',''usletter'',''orient'',''portrait'');');
disp(' ');
%Interactive merge figures
figure
figdesign(3,3,'type','usletter','orient','portrait');
msgbox('To merge axes, select FigDesign>Merge in the main figure menu bar. Left click on axes to merge, double-clicking on the last axis to complete merger. This process may repeated multiple times by reselecting FigDesign>Merge. Give it a try :)','Interactive Axis Merging');
disp('Press any key to continue...');
pause;
close all;

%%
clc
clc
disp('%****************************************************************');
disp('%  Using the interactive axis adjustment placement feature');
disp('%****************************************************************');
disp(' ');
disp('%Move sliders to adjust axes parameters or type in the edit boxes to enter specific numerical values.');
disp('%Values will be in units specificed by the ''units'' parameter.');
disp('%When the adjustment window is closed, interactive figure merging is enabled on the main figure.');
disp(' ');
disp('figure');
disp('figdesign(3,3,''type'',''usletter'',''orient'',''portrait'',''units'',''inches'',''margins'',[.05 .05 .1 .1 .05],''interact'',1);');
disp(' ');
disp('Close the main figure to the demo...');

%Interactive adjust page margins
figure;
figdesign(3,3,'type','usletter','orient','portrait','units','inches','margins',[.05 .05 .1 .1 .05],'interact',1);
msgbox('Move sliders to adjust axes parameters. Type in the edit boxes to enter specific numerical values. When the adjustment window is closed, interactive figure merging is enabled on the main figure.','Interactive Axes Adjustment');

%*****************************************************
%     FIGURE TO GET IN GRID AND LAYOUT INFO
%*****************************************************
function params = make_layout_fig()
% Create the main figure
layout_fig = figure('Name', 'Figure Designer', 'Units', 'pixel', 'Position', [769   403   433   246],'MenuBar', 'none', 'Resize', 'off');
% Set the figure's CloseRequestFcn callback
set(layout_fig, 'CloseRequestFcn', @close_layout_fig);

%Center figure
set(layout_fig,'units','normalized');
layout_fig.Position(1) = .5-layout_fig.Position(4)/2;
layout_fig.Position(2) = .5-layout_fig.Position(3)/2;

% Create edit fields for 'Row' and 'Column'
rowLabel = uicontrol(layout_fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.1, 0.85, 0.11, 0.1], 'String', 'Rows:');
rowEditField = uicontrol(layout_fig, 'Style', 'edit', 'Units', 'normalized', 'Position', [0.22, 0.85, 0.1, 0.1], 'String', '2');

colLabel = uicontrol(layout_fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.1, 0.7, 0.11, 0.1], 'String', 'Columns:');
colEditField = uicontrol(layout_fig, 'Style', 'edit', 'Units', 'normalized', 'Position', [0.22, 0.7, 0.1, 0.1], 'String', '2');

% Create radio button group for orientation
orientationGroup = uibuttongroup(layout_fig, 'Units', 'normalized', 'Position', [0.1, 0.2, 0.8, 0.4], 'Title', 'Select Orientation');

portraitRadioButton = uicontrol(orientationGroup, 'Style', 'radiobutton', 'Units', 'normalized', 'Position', [0.1, 0.7, 0.8, 0.2], 'String', 'Portrait'); %#ok<*NASGU>
landscapeRadioButton = uicontrol(orientationGroup, 'Style', 'radiobutton', 'Units', 'normalized', 'Position', [0.1, 0.4, 0.8, 0.2], 'String', 'Landscape');
fullscreenRadioButton = uicontrol(orientationGroup, 'Style', 'radiobutton', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.2], 'String', 'Full Screen');

% Create a 'Done' button
doneButton = uicontrol(layout_fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.4, 0.05, 0.2, 0.1], 'String', 'Done', 'Callback', @(src, event) button_callback(rowEditField, colEditField, orientationGroup, layout_fig));

% Store the result in the UserData property of the figure
result = [];
set(layout_fig, 'UserData', result);

% Set the figure's CloseRequestFcn callback
set(layout_fig, 'CloseRequestFcn', @close_layout_fig);

% Wait for the figure to close
uiwait(layout_fig);

% Retrieve the result from the UserData property
params = get(layout_fig, 'UserData');

%*****************************************************
%     BUTTON CALLBACK FOR THE LAYOUT FIGURE
%*****************************************************
function button_callback(rowEditField, colEditField, orientationGroup, layout_fig)
row = str2double(get(rowEditField, 'String'));
col = str2double(get(colEditField, 'String'));

try
    validateattributes(row, {'numeric'}, {'scalar', 'integer', 'positive'});
    validateattributes(col, {'numeric'}, {'scalar', 'integer', 'positive'});
catch
    msgbox('Row and column numbers must be postive integers.')
    return;
end

selectedRadioButton = get(get(orientationGroup, 'SelectedObject'), 'String');
orientation = '';
if strcmp(selectedRadioButton, 'Portrait')
    orientation = 'Portrait';
elseif strcmp(selectedRadioButton, 'Landscape')
    orientation = 'Landscape';
elseif strcmp(selectedRadioButton, 'Full Screen')
    orientation = 'Full';
end

%Save parameters
params.row = row;
params.col = col;
params.orientation = orientation;

% Store the result in the UserData property of the figure
set(layout_fig, 'UserData', {params, layout_fig})

% Close the figure
uiresume(layout_fig);

%*****************************************************
%     CLOSE FIGURE CALLBACK FOR THE LAYOUT FIGURE
%*****************************************************
function close_layout_fig(src, ~)
% Retrieve the figure handle
grid_fig = ancestor(src, 'figure');

% If the figure was closed without pressing the 'Done' button,
% set the result to a default value (if needed) and close it
if isempty(get(grid_fig, 'UserData'))
    set(grid_fig, 'UserData', []); % Set a default value if required
    uiresume(grid_fig);
end
delete(grid_fig)


%*****************************************************
%           GENERATE THE FIGURE CALL
%*****************************************************
function generate_call(mainfig_h)
params = mainfig_h.UserData.params;

fig_pos = get(mainfig_h,'Position');

%Create the call string
call_str = ['ax = figdesign(' num2str(params.num_rows) ', ' num2str(params.num_cols) ', ''PaperType'', ''' params.type ''', ''orient'', ''' params.orient ''' , ''margins'', [' num2str(params.margins) ']'];

%Add any mergers
if ~isempty(mainfig_h.UserData.merged)
    call_str = [call_str ', ''merge'', {'];

    array_str = cell2mat(cellfun(@(x)['[' num2str(x) '], '],mainfig_h.UserData.merged,'UniformOutput',false));
    call_str = [call_str array_str(1:end-2) '}'];
end

%Replicate the position
call_str = [call_str ', ''Position'', [' num2str(fig_pos) ']'];

%End the call string
call_str = [call_str ');'];

%Remove extra spaces
call_str = regexprep(call_str, '\s+', ' ');

%Display the figure call
disp('')
disp('To create this figure, enter the following in the command line:')
disp(call_str);
