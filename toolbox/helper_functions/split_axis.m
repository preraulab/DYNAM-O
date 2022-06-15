function new_axes = split_axis(varargin)
%SPLIT_AXIS Split an axis into multiple axes
%   new_axes = split_axis(hbreaks, vbreaks)
%              split_axis(ax, hbreaks, vbreaks)
%
% Inputs:
%   ax: handle to axis to split (default: current axis)
%   hbreaks: 1xH vector - horizontal partitions in % (left to right), must sum to 1 --required
%   vbreaks: 1xV vector -vertical partitions in % (bottom to top), must sum to 1 --required
%   delete_ax: logical - delete original axis (default: true)
%
% Outputs:
%   new_axes: array of handles to the new axis objects
%
%   Example:
%
%     figure
%     new_axes = split_axis([.1 .2 .4 .3], [.6 .2 .1 .1], true);
%
%     for ii = 1:length(new_axes)
%         new_axes(ii).Color = rand(1,3);
%     end
%
%   Copyright 2022 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Last modified 03/10/2022
%********************************************************************

% Parse possible axes input.
[ax, args, ~] = axescheck(varargin{:});

% Get handle to either the requested or a new axis.
if isempty(ax)
   ax = gca;
end

%Error check
assert(length(args)>= 2,'Must have at least two arguments')

hbreaks = args{1};
vbreaks = args{2};

if length(args)<3 || isempty(args{3})
    delete_ax = true;
else
    delete_ax = args{3};
end

%Normalize axis
ax.Units = 'normalized';

%Error check
assert(sum(vbreaks)==1,'Sum of vbreaks must equal 1');
assert(sum(hbreaks)==1,'Sum of hbreaks must equal 1');

%Get positions of original axis
L = ax.Position(1);
B = ax.Position(2);
W = ax.Position(3);
H = ax.Position(4);

Nv = length(vbreaks);
Nh = length(hbreaks);

%Counter for new axes
c = 1;

%Loop through all the partitions
for vv = 1:Nv
    for hh = 1:Nh

        %Create the new axis
        ax_new = axes;

        %Update left
        if vv == 1
            ax_new.Position(1) = L;
        else
            ax_new.Position(1) = L + sum(vbreaks(1:vv-1))*W;
        end

        %Update bottom
        if hh == 1
            ax_new.Position(2) = B;
        else
            ax_new.Position(2) = B + sum(hbreaks(1:hh-1))*H;
        end

        %Update width/height
        ax_new.Position(3) = W*(vbreaks(vv));
        ax_new.Position(4) = H*(hbreaks(hh));

        %%Good for debugging
        %ax_new.Color = rand(1,3);

        %Add to output vector
        new_axes(c) = handle(ax_new);
        c = c+1;
    end
end

%Hides original axis
if delete_ax
    delete(ax);
end