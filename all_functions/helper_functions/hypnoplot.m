function sh=hypnoplot(varargin)
% HYPNOPLOT Make a pretty plot of a hypnogram
%
%   Usage:
%       hyp_handle = hypnoplot(times, stages, groupNREM)
%       hyp_handle = hypnoplot(hypnostruct, groupNREM)
%
%   Input:
%       times: 1xN vector of stage times
%       stages: 1xN vector of stage values (0:Undefined, 5: Wake, 4:REM, 3:N1, 2:N2, 1:N3)
%       groupNREM: boolean - Use the same color for all NREM stages (default: true)
%       hypnostruct: structure with .time and .stage fields
%
%   Output:
%       hyp_handle: handle to stairs object for hypnogram
%
%
%   Example:
%         %Load example data
%         load('/data/preraugp/archive/Lunesta Study/sleep_stages/Lun01-Night1.mat');
%
%         %Make reduced hypnogram
%         t_inds=unique([1; find(diff(stage_struct.stage)~=0)+1; length(stage_struct.stage)]);
%
%         hyp_times=stage_struct.time(t_inds);
%         hyp_stages=stage_struct.stage(t_inds);
%
%         figure;
%         hypnoplot(hyp_times, hyp_stages);
%
%   Copyright 2022 Michael J. Prerau, Ph.D.
%
%   Last modified 06/02/2022
%% ********************************************************************

if isstruct(varargin{1})
    s=varargin{1};
    time=s.time(:)';
    stage=s.stage(:)';
    
    if nargin==2
        groupNREM=varargin{2};
    else
        groupNREM=true;
    end
elseif nargin>=2
    time=varargin{1}(:)';
    stage=varargin{2}(:)';
    
    if nargin==3
        groupNREM=varargin{3};
    else
        groupNREM=true;
    end
end

time =[time, time(end)+30];
stage=[stage, stage(end)];

%Simplify vector
inds=[1 find(diff(stage)~=0)+1 length(time)];

time=time(inds);
stage=stage(inds);

%Force all low/high stages to be undef/artifact respectively
stage(stage<0 | isnan(stage)) = 0;
stage(stage>6) = 6;

%Create hypnogram labes
hypnogram_labels={'Undef','N3','N2','N1','REM','Wake','Art'};

%Define the colors by stages
NS=[.9 .9 .9]; %No stage
W=[1 .7 .7];
N3=[.6 .6 1];
N2=[.8 .8 1];
N1=[.8 1  1];
REM=[.7 1 .7];
art = [.6 .6 .6]; % artifact

%Create color matrix
colors=[NS; ...
    N3; ...
    N2; ...
    N1; ...
    REM; ...
    W;...
    art];

%Plot the hypnogram
sh=stairs(time,stage,'k','linewidth',2);

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
buffer=.3;
min_y = val_min - buffer;
max_y = val_max + buffer;

set(gca,'ytick',val_min:val_max,'yticklabel',{hypnogram_labels{val_min+1:val_max+1}},'xticklabel','');

hold on;

if groupNREM %Merge all NREM 
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
    fill([a;b;b;a],[c;c;d;d],colors(stage_num + 1,:),'edgecolor','none')
end

%Keep hypnogram trace on top
uistack(sh,'top');

%Set the proper limits
if length(time) == 2
    xlim(time([1 end]));
else
    xlim(time([1 end-1]));
end

ylim([min_y max_y]);
