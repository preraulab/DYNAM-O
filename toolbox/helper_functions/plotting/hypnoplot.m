function sh = hypnoplot(stage_times,stage_vals,varargin)
% HYPNOPLOT Make a pretty plot of a hypnogram
%
%   Usage:
%       hyp_handle = hypnoplot(stage_times, stage_vals, <optional arguments>)
%
%   Input:
%       stage_times: 1xN vector of stage times
%             NOTE: Assumes each stage time indicates stage ONSET time, with an epoch ranging from
%             stage_times(t) to stage_times(t+1)
%       stage_vals: 1xN vector of stage values (6: Artifact 5: Wake, 4:REM, 3:N1, 2:N2, 1:N3, 0:Undefined)
%             NOTE: Stage are labeled in the plot order of the y-axis, so N1 = 3 and N3 = 1
%
%   Optional Name-Value Pairs:
%       'Artifacts': 1xT logical vector of artifacts, must include EITHER Fs or ArtifactTimes
%       'Fs': Sampling frequency for artifacts.
%             NOTE: Assumes time starts at 0, which is the time of the first stage
%       'ArtifactTimes': 1xT vector of time values for artifacts
%       'HypnogramLabels': 1x7 cell, stage name labels, default: {'Undef','N3','N2','N1','REM','Wake','Art'}
%       'LabelPos': 'top' or 'left', label position, default: 'left'
%       'StageColors': 7x3 double
%       'GroupNREMColors': logical, use one color for NREM vs different colors for N1-3, default: true
%       'PlotBuffer': double, axis gap on top/bottom, default: 0.3
%
%   Output:
%       hyp_handle: handle to stairs object for hypnogram
%
%   Example:
%       %Simulate a simple hypnogram
%       stage_vals = [0 0 0 5 5 5 4 3 2 2 2 1 2 1 2 3 5 5 5 1 5 1 2 5 3 2 1 4 4 4 5 4 0 3 2 1 1 5 5 5 0 0 0];
%       stage_vals(stage_vals <2) = 5;
%       stage_times = (0:length(stage_vals)-1)*30;
%
%       %Simulate some artifacts
%       Fs = 200;
%       dt = 1/Fs;
%       artifact_times = 0:dt:max(stage_times);
%       artifacts = rand(size(artifact_times))<.002;
%
%       figure
%       subplot(211)
%       hypnoplot(stage_times, stage_vals, 'Artifacts', artifacts, 'Fs', Fs);
%       subplot(212)
%       hypnoplot(stage_times, stage_vals,'HypnogramLabels', {'U','3','2','1','R','W','A'},'LabelPos','top', 'Artifacts', artifacts, 'ArtifactTimes', artifact_times);

%   Copyright 2024 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%% ********************************************************************

%% Parse input
%Check for old input
if isstruct(stage_times)
    hypnoplot(stage_times.time, stage_times.stage, varargin{2:end});
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

addRequired(p, 'stage_times', @(x) validateattributes(x, {'numeric'}, {'real','finite','nondecreasing','vector'}));
addRequired(p, 'stage_vals', @(x) validateattributes(x, {'numeric'}, {'real','finite','nonnegative','vector'}));
addOptional(p, 'Artifacts', logical([]), @(x) validateattributes(x,{'logical'},{'real','finite','2d'}));
addOptional(p, 'Fs', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addOptional(p, 'ArtifactTimes', [], @(x) validateattributes(x,{'numeric'},{'real','finite','2d'}));
addOptional(p, 'HypnogramLabels', {'Undef','N3','N2','N1','REM','Wake','Art'}, @(x) validateattributes(x,{'cell'},{'numel',7}));
addOptional(p, 'StageColors', default_colors, @(x) validateattributes(x,{'numeric'},{'real','finite','nonnegative','ncols',3}));
addOptional(p, 'PlotBuffer', .3, @(x) validateattributes(x,{'numeric'},{'real','finite','positive','scalar'}));
addOptional(p, 'LabelPos', 'left', @(x) any(validatestring(x, {'top', 'left'})));
addOptional(p, 'GroupNREMColors', true, @(x) validateattributes(x,{'logical'},{'scalar'}));

parse(p,stage_times,stage_vals,varargin{:});

% Manually assign variables
HypnogramLabels = p.Results.HypnogramLabels;
StageColors = p.Results.StageColors;
PlotBuffer = p.Results.PlotBuffer;
GroupNREMColors = p.Results.GroupNREMColors;
LabelPos = p.Results.LabelPos;
artifacts = p.Results.Artifacts;
Fs = p.Results.Fs;
artifact_times = p.Results.ArtifactTimes;

%Do additional input checks
if iscolumn(stage_vals) %Force stage_vals to be a row vector for the horizontal concatenation
    stage_vals = transpose(stage_vals);
end

%Make stage_vals as double class
if ~isa(stage_vals,'double')
    stage_vals = double(stage_vals);
end

assert(isequal(size(stage_times), size(stage_vals)), 'time and stage must be the same dimensions')

if ~isempty(artifacts)
    assert(xor(~isempty(Fs), ~isempty(artifact_times)), 'Must provide either sampling frequency or time vector for artifacts')
    if iscolumn(artifacts) %Force artifacts to be a row vector for the horizontal concatenation
        artifacts = transpose(artifacts);
    end
    if ~isempty(artifact_times)
        if iscolumn(artifact_times) %Force artifact_times to be a row vector for the interp1
            artifact_times = transpose(artifact_times);
        end
        assert(length(artifact_times) == length(artifacts), 'Artifact vector and times must be the same dimension');
    end
end

%% Make the hypnoplot
%Adds a 30s epoch at the end for plotting
stage_times(end+1) = stage_times(end)+30;
stage_vals(end+1) = stage_vals(end);

%Simplify vector
inds=[1 find(diff(stage_vals)~=0)+1 length(stage_times)];

stage_times=stage_times(inds);
stage_vals=stage_vals(inds);

%Force all low/high stages to be undef/artifact respectively
stage_vals(stage_vals<0 | isnan(stage_vals)) = 0;
stage_vals(stage_vals>6) = 6;

%Plot the hypnogram
sh = stairs(stage_times,stage_vals,'k','linewidth',2);

%Adjust plot to include no stage and artifacts
val_min = min([stage_vals,1]); %Always go down to at least N3
val_max = max(stage_vals);

%Set ylim range
min_y = val_min - PlotBuffer;
max_y = val_max + PlotBuffer;

hold on;

if strcmpi(LabelPos,'left')
    if ~isempty(artifacts)
        labels = HypnogramLabels(val_min+1:val_max+1);
        labels = [{'Art'} labels(:)'];
        set(gca,'ytick',[val_min-1 val_min:val_max],'yticklabel',labels,'xticklabel','');
    else
        set(gca,'ytick',val_min:val_max,'yticklabel',HypnogramLabels(val_min+1:val_max+1),'xticklabel','');
    end
else
    %Get just the stages that exist
    stage_list = unique(stage_vals);

    %Plot all the first letter at the top of the first instance
    for ss = 1:length(stage_list)
        stg = stage_list(ss);
        first_stage = find(stage_vals==stg,1,"first");

        text(stage_times(first_stage),max_y,HypnogramLabels{stg+1},'VerticalAlignment','baseline','HorizontalAlignment','center');
    end
    if isempty(artifacts)
        set(gca,'yticklabel','')
    else
        set(gca,'YTick',val_min-1,'YTickLabel','Art')
    end
end

if GroupNREMColors %Merge all NREM
    stage_vals(stage_vals==1 | stage_vals == 3) = 2;
end

for stage_num = 0:6 %Loop through all stages
    inds = find(stage_vals(1:end-1)==stage_num);

    %Get epoch times
    a = stage_times(inds);
    b = stage_times(inds+1);
    c = ones(1,length(a))*min_y;
    d = ones(1,length(a))*max_y;

    %Plot shaded rectangle
    fill([a;b;b;a],[c;c;d;d], StageColors(stage_num + 1,:),'edgecolor','none')
end
%Keep hypnogram trace on top
uistack(sh,'top');

%Plot the artifacts on the bottom
if ~isempty(artifacts)
    if ~isempty(Fs) && isempty(artifact_times)
        artifact_times = (0:length(artifacts)-1)/Fs; % this is a row vector
    end

    art_stage_inds = stage_vals == 6;
    if any(art_stage_inds)
        stage_vals(stage_vals ~= 6) = 0;
        art_stage = interp1(single(stage_times), single(stage_vals), artifact_times, 'previous', 'extrap');
        art_stage(isnan(art_stage)) = 0;
        artifacts = artifacts | art_stage;
    end

    %Simplify vector
    inds=[1 find(diff(artifacts)~=0)+1 length(artifacts)];
    artifacts = artifacts(inds);
    artifact_times = artifact_times(inds);

    inds = find(artifacts(1:end-1));

    %Get epoch times
    a = artifact_times(inds);
    b = artifact_times(inds+1);
    c = ones(1,length(a))*(val_min-1);
    d = ones(1,length(a))*min_y;

    %Plot shaded rectangle
    fill([a;b;b;a],[c;c;d;d], StageColors(6 + 1,:),'edgecolor','k')
end

%Set limits
axis tight
