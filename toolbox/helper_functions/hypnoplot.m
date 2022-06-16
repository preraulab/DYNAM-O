function sh = hypnoplot(time,stage,varargin)
% HYPNOPLOT Make a pretty plot of a hypnogram
%
%   Usage:
%       hyp_handle = hypnoplot(times, stages)
%
%   Input:
%       times: 1xN vector of stage times
%       stages: 1xN vector of stage values (6: Artifact 5: Wake, 4:REM, 3:N1, 2:N2, 1:N3, 0:Undefined)
%       
%       Optional Name-Value Pairs:
%       'HypnogramLabels': 1x7 cell, stage name labels, default: {'Undef','N3','N2','N1','REM','Wake','Art'}
%       'LabelPos': 'top' or 'left', label position, default: 'left'
%       'StageColors': 7x3 double
%       'GroupNREMColors': logical, use one color for NREM vs different colors for N1-3, default: true
%       'PlotBuffer': double, axis gap on top/bottom, default: 0.3
%
%   Output:
%       hyp_handle: handle to stairs object for hypnogram
%
%
%   Example:
%         stage = [0 0 0 5 4 3 2 2 6 6 6 2 1 2 3 5 6 5 6 5 6 6 5 5 3 2 1 4 4 6 5 4 0 3 2 1 1 0 0 6 nan];
%         time = (1:length(stage))*30;
%         
%         figure
%         subplot(211)
%         hypnoplot(time, stage);
%         
%         subplot(212)
%         hypnoplot(time, stage,'HypnogramLabels', {'U','3','2','1','R','W','A'},'LabelPos','top');
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Last modified 06/02/2022
%% ********************************************************************

%Check for old input
if isstruct(time)
    hypnoplot(time.time, time.stage, varargin{2:end});
    warning('Avoid using stage structure for input. Use separate time and stage variables')
    return;
end

%Default colors for plot
default_colors = [    0.9000    0.9000    0.9000; ...
    0.6000    0.6000    1.0000; ...
    0.8000    0.8000    1.0000; ...
    0.8000    1.0000    1.0000; ...
    0.7000    1.0000    0.7000; ...
    1.0000    0.7000    0.7000; ...
    0.6000    0.6000    0.6000];

p = inputParser;

addRequired(p,'time',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
addRequired(p,'stage',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
addParameter(p,'HypnogramLabels',{'Undef','N3','N2','N1','REM','Wake','Art'},@iscell);
addParameter(p,'StageColors',default_colors,@(x)validateattributes(x,{'numeric'},{'nonempty'}));
addParameter(p,'PlotBuffer', .3, @(x)validateattributes(x,{'numeric'},{'nonempty','positive'}));
addParameter(p,'LabelPos', 'left', @ischar);
addParameter(p,'GroupNREMColors',true, @islogical);

parse(p,time,stage,varargin{:});

HypnogramLabels = p.Results.HypnogramLabels;
StageColors = p.Results.StageColors;
PlotBuffer = p.Results.PlotBuffer;
LabelPos = p.Results.LabelPos;
GroupNREMColors = p.Results.GroupNREMColors;


%Do additional input checks
if iscolumn(stage)
    stage = stage';
end

if iscolumn(time)
    time = time';
end

assert(isequal(size(time),size(stage)),'time and stage must be the same dimensions')
assert(size(StageColors,2)==3,'Colors must be an N x 3 matrix')
assert(length(HypnogramLabels)==7,'Hypnogram labels must be a 1 x 7 cell of strings - Undefined, N3, N2, N1, R, W, Artifiact')
assert(ismember(lower(LabelPos),{'left','top'}),'LabelPos must be "left" or "top"')


%Adds a 30s epoch at the end for plotting
time(end+1) = time(end)+30;
stage(end+1) = stage(end);

%Simplify vector
inds=[1 find(diff(stage)~=0)+1 length(time)];

time=time(inds);
stage=stage(inds);

%Force all low/high stages to be undef/artifact respectively
stage(stage<0 | isnan(stage)) = 0;
stage(stage>6) = 6;

%Plot the hypnogram
sh = stairs(time,stage,'k','linewidth',2);

%Adjust plot to include no stage and artifacts
if any(~stage)
    val_min = 0;
else
    val_min = 1;
end

if any(stage==6)
    val_max = 6;
else
    val_max = 5;
end

%Set ylim range
min_y = val_min - PlotBuffer;
max_y = val_max + PlotBuffer;

hold on;

if GroupNREMColors %Merge all NREM
    stage(stage==1 | stage == 3) = 2;
end

for stage_num = 0:6 %Loop through all stages
    inds = find(stage(1:end-1)==stage_num);

    %Get epoch times
    a = time(inds);
    b = time(inds+1);
    c = ones(1,length(a))*min_y;
    d = ones(1,length(a))*max_y;

    %Plot shaded rectangle
    fill([a;b;b;a],[c;c;d;d], StageColors(stage_num + 1,:),'edgecolor','none')
end

%Keep hypnogram trace on top
uistack(sh,'top');

if strcmpi(LabelPos,'left')
    set(gca,'ytick',val_min:val_max,'yticklabel',HypnogramLabels(val_min+1:val_max+1),'xticklabel','');
else
    %Get just the stages that exist
    stage_list = unique(stage);

    %Plot all the first letter at the top of the first instance
    for ss = 1:length(stage_list)
        stg = stage_list(ss);
        first_stage = find(stage==stg,1,"first");

        text(time(first_stage),max_y,HypnogramLabels{stg+1},'VerticalAlignment','baseline','HorizontalAlignment','center');
    end
    set(gca,'yticklabel','')
end

%Set the proper limits
if length(time) == 2
    xlim(time([1 end]));
else
    xlim(time([1 end-1]));
end

ylim([min_y max_y]);
