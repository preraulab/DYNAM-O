function [h_scaleline, h_scalelabel]=scaleline(varargin)
%SCALELINE  Adds a scale line to the x or y axis of a figure. Line scales
%with zoom.
%
%   Usage:
%       [h_scaleline, h_scalelabel]=scaleline(ax,time)
%       [h_scaleline, h_scalelabel]=scaleline(ax,time,label)
%       [h_scaleline, h_scalelabel]=scaleline(ax,time,label,line_axis)
%       [h_scaleline, h_scalelabel]=scaleline(ax,time,label,line_axis,gap)
%
%   Input:
%   ax: Axis to which to add the line (default: gca)
%   time: Scale line length (in plot units)
%   label: Label text for scale line (default: blank)
%   line_axis: Axis to which the line is attached, 'x' or 'y' (default: 'x')
%   gap: Gap between line and axis in normalized units (default: .01)
%
%   Output:
%   h_scaleline: Handle to the scale line
%   h_scalelabel: Handle to the scale label
%
%   Example:
%
%       figure
%       plot(randn(1,10000)*10000)
%       axis tight;
%       xlabel('Time (seconds)');
%       ylabel('Voltage (V)');
%
%       %Add x and y scale lines
%       scaleline(gca,1000,'1000 seconds');
%       scaleline(gca,5000,'5000 V','y');
%
%       zoom;
%       msgbox('Zoom to change scale line limits');
%
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Last modified 10/23/2020
%********************************************************************
if ishandle(varargin{1}) && strcmp(get(varargin{1},'type'),'axes')
    ax=varargin{1};
    time=varargin{2};
    varargin=varargin(3:end);
else
    ax=gca;
    time=varargin{1};
    varargin=varargin(2:end);
end

%Set up defaults
params={[num2str(time) ' seconds'], 'x', .01};
params(1:length(varargin))=varargin;

%Get the rest of the parameters
[tstring, line_axis, gap]=params{:};

%Get axis position to determine the size of the scale line
axpos=get(ax,'position');

%For x-axis line
if strcmpi(line_axis,'x')
    set(ax,'xticklabel','');
    
    %Get the length of the line as a function of the size of the axis
    line_width=axpos(3)*(time/diff(xlim(gca)));
    
    %Compute the new position
    line_position(4)=0;
    line_position(3)=line_width;
    line_position(2)=axpos(2)-gap;
    line_position(1)=axpos(1);
    
    %Create the line
    h_scaleline=annotation(get(ax,'parent'),'line','position',line_position,'linewidth',3);
    
    %Set the text to be centered
    text_position=line_position;
    text_position(4)=.01;
    text_position(2)=line_position(2)-text_position(4);
    
    %Create the text label
    h_scalelabel=annotation(get(ax,'parent'),'textbox',...
        min(text_position,1),...
        'String',tstring,...
        'HorizontalAlignment','center',...
        'FitBoxToText','off',...
        'EdgeColor','none','backgroundcolor','none');
    
    %Create listeners for the XLim property to scale the lines
    h=handle(ax);
    if verLessThan('matlab', '8.4')
        l1=handle.listener(h,findprop(h,'XLim'),'PropertyPostSet',@(obj,event)xscale_line(obj,event,ax,time,gap,h_scaleline,h_scalelabel));
        l2=handle.listener(h,'objectchildadded',@(obj,event)scale_line(obj,event,ax,time,gap,h_scaleline,h_scalelabel));
        
        setappdata(h,'xaxislisteners',{l1 l2});
    else
        l1=addlistener(h,findprop(h,'XLim'),'PostSet',@(obj,event)xscale_line(obj,event,ax,time,gap,h_scaleline,h_scalelabel));
        
        setappdata(h,'xaxislisteners',{l1});
    end
else %For a y-axis line
    set(ax,'yticklabel','');
    
    %Get the length of the line as a function of the size of the axis
    line_height=axpos(4)*(time/diff(ylim(gca)));
    
    %Compute the new position
    line_position(4)=line_height;
    line_position(3)=0;
    line_position(2)=axpos(2);
    line_position(1)=axpos(1)-gap;
    
    %Create the line
    h_scaleline=annotation(get(ax,'parent'),'line','position',line_position,'linewidth',3);
    
    %Set the text to be centered
    tpos=[-4*gap line_height/2 0];
    
    %Create the text label. Usese a text box to get at the rotation
    h_scalelabel=text(0,0,tstring,'rotation',90,'units','normalized','position',tpos,'verticalalign','middle','horizontalalign','center');
    
    axpos=get(ax,'position');
    h=axpos(4)*(time/diff(ylim(gca)));
    %Set the text to be centered
    tpos=[-4*gap h/2 0];
    h_scalelabel.Position = tpos;
    
    %Create listeners for the YLim property to scale the lines
    h=handle(ax);
    if verLessThan('matlab', '8.4')
        l1=handle.listener(h,findprop(h,'YLim'),'PropertyPostSet',@(obj,event)yscale_line(obj,event,ax,time,gap,h_scaleline,h_scalelabel));
        l2=handle.listener(h,'objectchildadded',@(obj,event)scale_line(obj,event,ax,time,gap,h_scaleline,h_scalelabel));
        
        setappdata(h,'yaxislisteners',{l1 l2});
    else
        l1=addlistener(h,findprop(h,'YLim'),'PostSet',@(obj,event)yscale_line(obj,event,ax,time,gap,h_scaleline,h_scalelabel));
        
        setappdata(h,'yaxislisteners',{l1});
    end
end

%Listener callback function to scale the line on XLim change
function xscale_line(~,~,ax,time,gap,h_scaleline,h_scalelabel)
axpos=get(ax,'position');

line_width=axpos(3)*(time/diff(xlim(gca)));

line_position(4)=0;
line_position(3)=line_width;
line_position(2)=axpos(2)-gap;
line_position(1)=axpos(1);

set(h_scaleline,'position',line_position);
set(h_scalelabel,'position',line_position);

%Listener callback function to scale the line on YLim change
function yscale_line(~,~,ax,time,gap,h_scaleline,h_scalelabel)
axpos=get(ax,'position');

h=axpos(4)*(time/diff(ylim(gca)));

line_position(4)=h;
line_position(3)=0;
line_position(2)=axpos(2);
line_position(1)=axpos(1)-gap;

set(h_scaleline,'position',line_position);

text_position=[-4*gap h/2 0];
set(h_scalelabel,'position',text_position');