function [zslider, pslider, zedit, pedit, zlabel, plabel, zlstnr, plstnr]=scrollzoompan(ax, dir, zoom_fcn, pan_fcn, bounds)
%SCROLLZOOMPAN  Adds pan and zoom scroll bars to an axis
%               mouse wheel = pan, shift + mouse wheel = zoom
%
%   Usage:
%   [zslider, pslider, zedit, pedit, zlabel, plabel, zlstnr, plstnr] = scrollzoompan(ax, dir, zoom_fcn, pan_fcn)
%
%   Input:
%   ax: Axis to zoom and pan (default: gca)
%   dir: Zoom/pan direction {'x','y'} (default: 'x')
%   zslider/pslider: Handles to slider object handles (default: creates at figure bottom)
%   zoom_fcn/pan_fcn: Handles to functions to be called on zoom or pan
%
%   Output:
%   zslider: Zoom slider handle
%   pslider: Pan slider handle
%   zedit: Zoom edit handle
%   pedit: Pan edit handle
%   zlabel: Zoom text label handle
%   plabel: Pan text label handle
%   zlstnr: Zoom slider listener
%   plstnr: Pan slider listener
%
%   Example:
%
%     figure
%     plot(randn(1,1000));
%     scrollzoompan;
%
%     figure
%     imagesc(peaks(1000));
%     scrollzoompan(gca,'y');
%
%  Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%**************************************************************************

%Set default axes to current
if nargin==0
    ax=gca;
end

%Set default direction to x
if nargin<2
    dir=lower('x');
end

%Set blank callbacks
if nargin<3
    zoom_fcn=[];
end

if nargin<4
    pan_fcn=[];
end

%Get current figure
fig_h = get(ax,'parent');
if ~isa(fig_h,'matlab.ui.Figure')
    fig_h = gcf;
end

%Get full data limits depending on direction
if strcmpi(dir,'x')
    xl=xlim(ax(1));

    amin=xl(1);
    amax=xl(2);
else
    yl=ylim(ax(1));

    amin=yl(1);
    amax=yl(2);
end

%Impose bounds if defined
if nargin<5
    bounds=[nan nan];
end

if ~isnan(bounds(1))
    amin=bounds(1);
end

if ~isnan(bounds(2))
    amax=bounds(2);
end

%Save the data in the figure
handle=guidata(fig_h);
handle.shift_down=false; %Checks if you are holding down shift
guidata(fig_h,handle);

fig_h.Visible = false;

%Find all the axes
ax_all = findall(fig_h,'type','axes');

%Set axes to absolute units
set(fig_h,'Units','inches');
set(ax_all,'Units','inches');

%Add 10% to the figure size
shift = fig_h.Position(4)*.1;
fig_h.Position(4) = fig_h.Position(4)+ shift;

pause(.1) %Pause needed to wait for resizing

%Shift all the axes up
for ii = 1:length(ax_all)
    ax_all(ii).Position(2) = ax_all(ii).Position(2)+shift;
end

shift = 0.04;

%Create zoom/pan sliders
zslider = uicontrol('style','slider','units','normalized','position',[0.0702 0.0262 0.8273 0.0232],'min',1e-50,'max',amax,'value',amax);
pslider = uicontrol('style','slider','units','normalized','position',[0.0702 0.0262+shift 0.8273 0.0232],'min',amin,'max',amax,'value',amax/2);

%Create zoom/pan edit boxes
zedit = uicontrol(fig_h,'style','edit','units','normalized','position',[0.9107 0.0147 0.0823 0.0422]);
pedit = uicontrol(fig_h,'style','edit','units','normalized','position',[0.9107 0.0147+shift 0.0823 0.0422],'callback',@(src,evnt)pan_edit(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn));

set(zedit,'callback',@(src,evnt)zoom_edit(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn));
set(pedit,'callback',@(src,evnt)pan_edit(ax, pslider, pedit, dir, pan_fcn));

zedit.String = zslider.Value;
pedit.String = pslider.Value;

%Create text labels
zlabel = uicontrol(fig_h,'style','text','string','Zoom','units','normalized','position', [0.0086 0.0071 0.0628 0.0449],'fontsize',12,'HorizontalAlignment','left','BackgroundColor',get(fig_h,'Color'));
plabel = uicontrol(fig_h,'style','text','string','Pan','units','normalized','position', [0.0086 0.0071+shift 0.0628 0.0449],'fontsize',12,'HorizontalAlignment','left','BackgroundColor',get(fig_h,'Color'));


%Add listeners for continuous value changes
zlstnr=addlistener(zslider,'ContinuousValueChange',@(src,evnt)zoom_slider(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn));
plstnr=addlistener(pslider,'ContinuousValueChange',@(src,evnt)pan_slider(ax, pslider, pedit, dir, pan_fcn));
set(fig_h,'WindowKeyPressFcn',{@handle_keys,ax, zslider, pslider, zedit, pedit, dir, zoom_fcn, pan_fcn},'WindowKeyReleaseFcn',@key_off);

set(fig_h,'WindowScrollWheelFcn',{@figScroll,ax, zslider, pslider, zedit, pedit, dir, zoom_fcn, pan_fcn});


%Return to normalized
set(fig_h,'Units','normalized');
set(ax_all,'Units','normalized');

fig_h.Visible = true;

%***********************************************************
%***********************************************************
%                  SLIDER FUNCTIONS
%***********************************************************
%***********************************************************
%-----------------------------------------------------------
%           CALLBACK TO HANDLE TIME SCALE ZOOM
%-----------------------------------------------------------
function zoom_slider(ax, zslider, pslider, zedit, pedit, dir, zoom_fcn)
%Keep the window center with window width determined by slider value
newlims=get(pslider,'value')+get(zslider,'value')/2*[-1 1];

amin=get(zslider,'min');
amax=get(zslider,'max');

%Sets a minimum window width
if newlims(2)<=newlims(1)
    newlims(2)=newlims(1)+1e-10;
end

if length(ax)>1
    ax = ax(1);
end

%Set sliderbounds so that you can't go past limits
if get(pslider,'value')-abs(diff(xlim(ax)))/2<amin
    newpos=amin+abs(diff(xlim(ax)))/2;
    set(pslider,'value', newpos);
    newlims(1)=amin;
elseif get(pslider,'value')+abs(diff(xlim(ax)))/2>amax
    newpos=amax-abs(diff(xlim(ax)))/2;
    set(pslider,'value', newpos);
    newlims(2)=amax;
end

%Compute the new limits
if strcmpi(dir,'x')
    set(ax,'xlim',newlims);
    set(pslider,'sliderstep',diff(xlim)/amax*[.5 1]);
else
    set(ax,'ylim',newlims);
    set(pslider,'sliderstep',diff(ylim)/amax*[.5 1]);
end

zedit.String = num2str(zslider.Value);
pedit.String = num2str(pslider.Value);

if ~isempty(zoom_fcn)
    feval(zoom_fcn);
end

%-----------------------------------------------------------
%           CALLBACK TO HANDLE TIME SCALE SCROLL
%-----------------------------------------------------------
function pan_slider(ax, pslider, pedit, dir, pan_fcn)
amin=get(pslider,'min');
amax=get(pslider,'max');

if length(ax)>1
    ax = ax(1);
end

%Set the limits to the slider value center
if strcmpi(dir,'x')
    %Set sliderbounds so that you can't go past limits
    if get(pslider,'value')-abs(diff(xlim(ax)))/2<amin
        set(pslider,'value',amin+abs(diff(xlim(ax)))/2);
    elseif get(pslider,'value')+abs(diff(xlim(ax)))/2>amax
        set(pslider,'value',amax-abs(diff(xlim(ax)))/2);
    end

    set(ax, 'xlim', get(pslider,'value')+[-1 1]*abs(diff(xlim(ax)))/2);
else
    %Set sliderbounds so that you can't go past limits
    if get(pslider,'value')-abs(diff(ylim(ax)))/2<amin
        set(pslider,'value',amin+abs(diff(ylim(ax)))/2);
    elseif get(pslider,'value')+abs(diff(ylim(ax)))/2>amax
        set(pslider,'value',amax-abs(diff(ylim(ax)))/2);
    end
    set(ax, 'ylim', get(pslider,'value')+[-1 1]*abs(diff(ylim(ax)))/2);
end

pedit.String = num2str(pslider.Value);

if ~isempty(pan_fcn)
    feval(pan_fcn);
end

%-----------------------------------------------------------
%           CALLBACK TO HANDLE TIME EDIT ZOOM
%-----------------------------------------------------------
function zoom_edit(ax, zslider, pslider, zedit, pedit, dir, zoom_fcn)
value = str2double(zedit.String);

amin=get(zslider,'min');
amax=get(zslider,'max');
value = max(min(value,amax),amin);

zslider.Value = value;
zoom_slider(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn);

%-----------------------------------------------------------
%           CALLBACK TO HANDLE TIME EDIT PAN
%-----------------------------------------------------------
function pan_edit(ax, pslider, pedit, dir, pan_fcn)
value = str2double(pedit.String);

amin=get(pslider,'min');
amax=get(pslider,'max');
value = max(min(value,amax),amin);

pslider.Value = value;
pan_slider(ax, pslider, pedit, dir, pan_fcn);


%-----------------------------------------------------------
%           CALLBACK TO HANDLE SCROLL WHEEL
%-----------------------------------------------------------
function figScroll(~,callbackdata,ax, zslider, pslider, zedit, pedit, dir, zoom_fcn, pan_fcn)
if length(ax)>1
    ax = ax(1);
end

handle=guidata(get(ax,'parent'));

%Scroll if shift not pressed
if ~(handle.shift_down)
    amin=get(pslider,'min');
    amax=get(pslider,'max');
    if callbackdata.VerticalScrollCount > 0
        set(pslider,'value',min(get(pslider,'value')*(1+.025*callbackdata.VerticalScrollAmount),amax));
       pan_slider(ax, pslider, pedit, dir, pan_fcn);
    elseif callbackdata.VerticalScrollCount < 0
        set(pslider,'value',max(get(pslider,'value')*(1-.025*callbackdata.VerticalScrollAmount),amin));
        pan_slider(ax, pslider, pedit, dir, pan_fcn);
    end
    %Zoom if shift is pressed
else
    amin=get(zslider,'min');
    amax=get(zslider,'max');
    if callbackdata.VerticalScrollCount > 0
        set(zslider,'value',max(get(zslider,'value')*(1-.025*callbackdata.VerticalScrollAmount),amin));
        zoom_slider(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn);
    elseif callbackdata.VerticalScrollCount < 0
        set(zslider,'value',min(get(zslider,'value')*(1+.025*callbackdata.VerticalScrollAmount),amax));
        zoom_slider(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn);
    end
end

%-----------------------------------------------------------
%           SCROLL AND ZOOM WITH KEYS
%-----------------------------------------------------------
function handle_keys(~,event,ax, zslider, pslider, zedit, pedit, dir, zoom_fcn, pan_fcn)
if length(ax)>1
    ax = ax(1);
end
handle=guidata(get(ax,'parent'));

%Check if shift is bing pressed
handle.shift_down=(strcmpi(event.Key,'shift'));

winsize = get(zslider,'value')*2;
pos = get(pslider,'value');
pmax = get(pslider,'max');
pmin = get(pslider,'min');
zmax = get(zslider,'max');
zmin = get(zslider,'min');

switch event.Key
    %Scroll left
    case 'rightarrow'
        pnew = pos+winsize;
        set(pslider,'value',min(pnew,pmax));
        pan_slider(ax, pslider, pedit, dir, pan_fcn);
    %Scroll right
    case 'leftarrow'
        pnew = pos-winsize; 
        set(pslider,'value',max(pnew,pmin));
        pan_slider(ax, pslider, pedit, dir, pan_fcn);
    %Zoom in
    case 'downarrow'
        set(zslider,'value',max(get(zslider,'value')*(1-.025),zmin));
        zoom_slider(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn);
   %Zoom out
    case 'uparrow'
        set(zslider,'value',min(get(zslider,'value')*(1+.025),zmax));
        zoom_slider(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn);
    case 'z'
        %Get the initials of the scorer to be used for saving
        prompt={'Enter Window Size:';};
        name='Set Window Size';
        numlines=1;
        defaultanswer={''};
        answer=inputdlg(prompt,name,numlines,defaultanswer);

        if isempty(answer)
            return;
        end

        new_width = str2double(answer{1});
        if isnan(new_width)
            return;
        end

        set(zslider,'value',new_width);
        zoom_slider(ax, zslider, pslider, zedit, pedit, dir,zoom_fcn);

end

guidata(gcf,handle);

%-----------------------------------------------------------
%                TURN OFF SHIFT
%-----------------------------------------------------------
function key_off(~,~)
handle=guidata(gcf);
handle.shift_down=false;
guidata(gcf,handle);
