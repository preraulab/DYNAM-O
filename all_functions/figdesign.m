%FIGDESIGN  Simple, interactive design tool for figure and axes. Can format grids of axes,
%           as well as merge existing axes.
%
%   Usage:
%       axis_handles=figdesign([num_rows, num_cols], options)
%       axis_handles=figdesign(num_rows, num_cols, options)
%       axis_handles=figdesign(num_rows, num_cols, margins, options)
%
%   Input:
%   num_rows: the number of rows in the subplot
%   num_cols: the number of columns in the subplot
%
%   Options:
%   iteract: a boolean, which enables/disables grid interaction window (default: false).
%            Closing the interaction window actives interactive merging.
%            menu option on main figure.
%
%            To get new figure handles after interactive mergine, use:
%               axes_handles=figdesign('handles');
%   margins: a vector of margin size defined as [top bottom left right middle]
%            (default: [.1 .05 .08 .05 .08])
%   units: a string defining the units of the margin vector (default: 'normalized')
%   merge: a array or cell array, with indices of axes to merge
%   type: defines paper type for figure
%   orient: defindes paper orientation (default: portrait)
%
%   Output:
%   axis_handles: 1x(num_rows*numcols) vector of axis handles
%
%   TO RUN DEMO:
%       figdesign demo
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
%             middle=.08;
%
%             %Create subplot
%             figdesign(2,2,[top bottom left right middle]);
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
%             msgbox('Under the figure menu, select Merge Axes>Merge. Single click on axes to merge. Double click on the last axis to complete merger.');
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
%   Copyright 2021 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   last modified 05/15/2013
%********************************************************************
function axis_handles=figdesign(num_rows,num_cols,varargin)
%Run demo
if nargin==1
    if strcmpi(num_rows,'demo')
        demo();
        return;
    elseif strcmpi(num_rows,'handles');
        axis_handles=findobj(gcf,'type','axes');
        apos=get(axis_handles,'position');
        apos=reshape([apos{:}],4,numel([apos{:}])/4)';
        [~,ind]=sortrows(apos,2);
        axis_handles=axis_handles(flipud(ind));
        return
    end
end

%Parse input options
p=inputParser;
p.addOptional('margins',[.05 .05 .08 .05 .08 .08],@(x)any(isnumeric(x)));
p.addOptional('interact',false,@logical);
p.addOptional('units','normalized',@(x)any(strcmpi(x,{'normalized', 'inches', 'centimeters', 'points'})))
p.addOptional('merge','');
p.addOptional('orient','portrait', @(x)any(validatestring(x,{'portrait','landscape'})));
p.addOptional('type', []);
p.addOptional('numberaxes', false);

p.parse(varargin{:});

margins=p.Results.margins;
interact=logical(p.Results.interact);
units=p.Results.units;
merge=p.Results.merge;
orientation=p.Results.orient;
paper_type=p.Results.type;
numberaxes = p.Results.numberaxes;

%Check for one argument
if nargin==1
    %check if it's [num_rows, num_cols]
    if length(num_rows)==2
        num_cols=num_rows(2);
        num_rows=num_rows(1);
        %make the best matrix if just the number of plots
    elseif length(num_rows)==1
        [num_rows, num_cols]=spconfig(num_rows);
    end
end

%Get main figure
mainfig=gcf;
if ~isempty(paper_type)
    %Create figure
    set(mainfig,'paperorientation',orientation,'paperunits','inches','papertype',paper_type)
    set(mainfig,'units','inches','position',[0 0 get(gcf,'papersize')],'color','w');
end

if length(margins)~= 5 && length(margins) ~=6
    error('Margins must have 5 or 6 elements');
end

if length(margins) == 5
    margins(6) = margins(5);
end

set(mainfig,'units',units);
set(mainfig,'paperpositionmode','auto');
%Set up axesaxis_handles
axis_handles=create_axes(mainfig, margins(1),margins(2),margins(3),margins(4), margins(5), margins(6), num_cols, num_rows, units);

%Disable interaction for merged
if ~isempty(merge)
    if interact
        disp('Interaction disabled for merged axes');
        interact=false;
    end
    
    if ~iscell(merge)
        merge_axes(axis_handles(merge));
    else
        for i=1:length(merge)
            merge_axes(axis_handles(merge{i}));
        end
    end
    axis_handles=findobj(gcf,'type','axes');
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
    if ~strcmpi(units,'normalized')
        pos=get(mainfig,'position');
        wmax=pos(3);
        hmax=pos(4);
    else
        hmax=1;
        wmax=1;
    end
    
    %Create the position interaction figure
    posfig = figure('Position',[250 250 350 280],...
        'MenuBar','none','NumberTitle','off',...
        'Name','Adjust Subplots','closerequestfcn',@(src,evnt)merge_on(mainfig));
    
    %Create the sliders
    topslider_h = uicontrol(posfig,'units','pixel','Style','slider',...
        'Max',hmax,'Min',1e-100,'Value',margins(1),...
        'SliderStep',[0.05 0.2],...
        'Position',[25 25 300 20]);
    bottomslider_h = uicontrol(posfig,'units','pixel','Style','slider',...
        'Max',hmax,'Min',1e-100,'Value',margins(2),...
        'SliderStep',[0.05 0.2],...
        'Position',[25 75 300 20]);
    leftslider_h = uicontrol(posfig,'units','pixel','Style','slider',...
        'Max',wmax,'Min',1e-100,'Value',margins(3),...
        'SliderStep',[0.05 0.2],...
        'Position',[25 125 300 20]);
    rightslider_h = uicontrol(posfig,'units','pixel','Style','slider',...
        'Max',wmax,'Min',1e-100,'Value',margins(4),...
        'SliderStep',[0.05 0.2],...
        'Position',[25 175 300 20]);
    midslider_h = uicontrol(posfig,'units','pixel','Style','slider',...
        'Max',max([wmax hmax]),'Min',1e-100,'Value',margins(5),...
        'SliderStep',[0.05 0.2],...
        'Position',[25 225 300 20]);
    
    %Array of all slider handles
    sliders_h=[topslider_h bottomslider_h leftslider_h rightslider_h midslider_h];
    
    %Create descriptor texts for the sliders
    uicontrol(gcf,'units','pixel','Style','text','string','Top Margin','Position',[25 45 100 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','left');
    uicontrol(gcf,'units','pixel','Style','text','string','Bottom Margin','Position',[25 95 100 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','left');
    uicontrol(gcf,'units','pixel','Style','text','string','Left Margin','Position',[25 145 100 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','left');
    uicontrol(gcf,'units','pixel','Style','text','string','Right Margin','Position',[25 195 100 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','left');
    uicontrol(gcf,'units','pixel','Style','text','string','Middle Margins','Position',[25 245 100 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','left');
    
    %Create the edit boxes for manual entry of parameter values
    topedit_h=uicontrol(gcf,'units','pixel','Style','edit','string',num2str(margins(1)),'Position',[120 47 70 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','right');
    bottomedit_h=uicontrol(gcf,'units','pixel','Style','edit','string',num2str(margins(2)),'Position',[120 97 70 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','right');
    leftedit_h=uicontrol(gcf,'units','pixel','Style','edit','string',num2str(margins(3)),'Position',[120 147 70 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','right');
    rightedit_h=uicontrol(gcf,'units','pixel','Style','edit','string',num2str(margins(4)),'Position',[120 197 70 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','right');
    midedit_h=uicontrol(gcf,'units','pixel','Style','edit','string',num2str(margins(5)),'Position',[120 247 70 20],'backgroundcolor',get(gcf,'color'),'horizontalalign','right');
    
    %Array of all edit box handles
    editboxes_h=[topedit_h bottomedit_h leftedit_h rightedit_h midedit_h];
    
    %Set the edit box callbacks
    set(topedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,1, mainfig, num_cols, num_rows, units));
    set(bottomedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,2, mainfig, num_cols, num_rows, units));
    set(leftedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,3, mainfig, num_cols, num_rows, units));
    set(rightedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,4, mainfig, num_cols, num_rows, units));
    set(midedit_h,'callback',@(src,evnt)edit_update(axis_handles,sliders_h,editboxes_h,5, mainfig, num_cols, num_rows, units));
    
    %Set continuous callbaxs for the sliders
    addlistener(topslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,1, mainfig, num_cols, num_rows, units));
    addlistener(bottomslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,2, mainfig, num_cols, num_rows, units));
    addlistener(leftslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,3, mainfig, num_cols, num_rows, units));
    addlistener(rightslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,4, mainfig, num_cols, num_rows, units));
    addlistener(midslider_h,'ContinuousValueChange',@(src,evnt)slider_update(axis_handles,sliders_h,editboxes_h,5, mainfig, num_cols, num_rows, units));
    
    %Fix the main figure so that it closes the adjustment window when
    %deleted
    set(mainfig,'closerequestfcn',@(src,evnt)close_all(mainfig, posfig));
else
    %If not adjusting, add the merge menu to the main figure toolbar
    f = uimenu('Label','Merge Axes');
    uimenu(f,'Label','Merge...','Callback',@(src,evnt)merge_axes);
    
    % Add numbers to axes for easy identification
    if numberaxes
        for ii = 1:length(axis_handles)
            title(axis_handles(ii), num2str(ii));
        end
    end
    
end

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

%*****************************************************
%                CREATE GRID OF AXES
%*****************************************************
function axis_handles=create_axes(mainfig_h, top_margin, bottom_margin, left_margin, right_margin, midh_margin, midv_margin, num_cols, num_rows, units)
%Get the max and min figure bounds
if ~strcmpi(units,'normalized')
    pos=get(mainfig_h,'position');
    wmax=pos(3);
    hmax=pos(4);
else
    hmax=1;
    wmax=1;
end

%Compute the height and width for the axes
ax_width=(wmax-left_margin-right_margin-midh_margin*(num_cols-1))/num_cols;
ax_height=(hmax-top_margin-bottom_margin-midv_margin*(num_rows-1))/num_rows;

%Set up output vector
num_axes=num_cols*num_rows;
axis_handles=zeros(1,num_axes);

%Loop through each axis and define properties
ax_number=1; %Counter
for r=1:num_rows
    for c=1:num_cols
        if ax_number<=num_axes
            %Compute left and bottom coordinates
            left=left_margin+midh_margin*(c-1)+ax_width*(c-1);
            bottom=hmax-top_margin-midv_margin*(r-1)-ax_height*r;
            
            %Create new axis
            axis_handles(ax_number)=axes('units',units,'position',[left bottom ax_width ax_height]);
            
            %Update counter
            ax_number=ax_number+1;
        end
    end
end

%*****************************************************
%     UPDATE SLIDERS AND FIGURE WHEN TEXT IS EDITED
%*****************************************************
function edit_update(axs, slider_h, edit_h, value, mainfig_h, num_cols, num_rows, units)
%Get the new value from the edited text box
newval=get(edit_h(value),'string');

%Set the slider to the appropriate value
set(slider_h(value),'value',str2double(newval));
slider_update(axs, slider_h, edit_h, value, mainfig_h, num_cols, num_rows,units);

%*****************************************************
%             MERGE SELECTED AXES
%*****************************************************
function merge_axes(merger_axes)
%Interactive selection of merger axes
if nargin==0
    %If interactive selection is on
    disp('Click to select axes. Double click on final axis to merge...');
    %Create log of axes clicked
    handle=guidata(gcf);
    handle.axes=[];
    guidata(gcf,handle);
    
    %Get the axes in the figure
    all_axes=findobj(gcf,'type','axes');
    %Allow them to accept clicks
    set(all_axes,'buttondownfcn',@select_axes);
    
    %Pause until double click
    uiwait(gcf);
    
    %Grab axes to be merged
    handle=guidata(gcf);
    merger_axes=handle.axes;
end

%Get axes units
units=get(merger_axes(1),'units');

%Warning check for number of axes
if length(merger_axes)==1
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

%Delete original axes and create new
delete(merger_axes)
new_axis=axes('units',units,'position',new_pos);

%Put new axisbelow other axes
uistack(new_axis,'bottom');

%*****************************************************
%        HELPER FUNCTION FOR AXIS SELECTION
%*****************************************************
function select_axes(varargin)
%Add selected axis to data
handle=guidata(gcf);
handle.axes=unique([handle.axes gca]);
guidata(gcf,handle);

%Continue merging
if strcmpi(get(gcf,'selectiontype'),'open')
    uiresume(gcf);
end

%*****************************************************
%   TURN ON MERGE MENU WHEN ADJUSTMENT WINDOW CLOSES
%*****************************************************
function merge_on(mainfig_h)
delete(gcf)
figure(mainfig_h)
f = uimenu('Label','Merge Axes');
uimenu(f,'Label','Merge...','Callback',@(src,evnt)merge_axes);

%*****************************************************
%               PROPERLY CLOSE WINDOWS
%*****************************************************
function close_all(mainfig_h, posfig_h)
delete(mainfig_h)
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
disp('middle=.2;');
disp(' ');
disp('%Create grid of axes with custom margins');
disp('figdesign(2,2,[top bottom left right middle]);');
disp(' ');
disp('%NOTE: Can also be: figdesign(2,2,''margins'',[top bottom left right middle]);');
disp(' ');

figure;
%Define custom margins
top=.1;
bottom=.1;
left=.1;
right=.1;
middle=.2;

%Create subplot
figdesign(2,2,[top bottom left right middle]);
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
disp('%To merge axes, select Merge Axes>Merge in the main figure menu bar. Left click on axes to merge, double-clicking on the last axis to complete merger.');
disp('%This process may repeated multiple times by reselecting Merge Axes>Merge. Give it a try :)');
disp(' ');
disp('figure');
disp('figdesign(3,3,''type'',''usletter'',''orient'',''portrait'');');
disp(' ');
%Interactive merge figures
figure
figdesign(3,3,'type','usletter','orient','portrait');
msgbox('To merge axes, select Merge Axes>Merge in the main figure menu bar. Left click on axes to merge, double-clicking on the last axis to complete merger. This process may repeated multiple times by reselecting Merge Axes>Merge. Give it a try :)','Interactive Axis Merging');
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
disp('figdesign(3,3,''type'',''usletter'',''orient'',''portrait'',''units'',''inches'',''margins'',[.5 .5 1 1 .5],''interact'',1);');
disp(' ');
disp('Close the main figure to the demo...');

%Interactive adjust page margins
figure;
figdesign(3,3,'type','usletter','orient','portrait','units','inches','margins',[.5 .5 1 1 .5],'interact',1);
msgbox('Move sliders to adjust axes parameters. Type in the edit boxes to enter specific numerical values. When the adjustment window is closed, interactive figure merging is enabled on the main figure.','Interactive Axes Adjustment');
