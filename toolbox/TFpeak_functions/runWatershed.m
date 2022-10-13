function Ldata = runWatershed(data, bl_thresh, f_verb, verb_pref, f_disp)
% RUNWATERSHED determines peak regions using matlab watershed function.
%
% Usage:
%   Ldata = runWatershed(data, bl_thresh, f_verb, verb_pref, f_disp)
%
% INPUTS:
%   data   -- 2D matrix of image data. defaults to peaks(100).
%   bl_thresh  -- power threshold used to cut off low power data to speed
%                 up computation. Default = [];
%   f_verb -- flag indicator whether to output text statements of progress.
%             0 - no output. 1 - output current function level.
%             defaults to 0. 
%   verb_pref -- prefix string for verbose output. defaults to ''.
%   f_disp -- flag indicator whether to plot. 
%             defaults to false, unless using default data.
% OUTPUTS:
%   Ldata: labeled region data
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Please provide the following citation for all use:
%       Patrick A Stokes, Preetish Rath, Thomas Possidente, Mingjian He, Shaun Purcell, Dara S Manoach, 
%       Robert Stickgold, Michael J Prerau, Transient Oscillation Dynamics During Sleep Provide a Robust Basis 
%       for Electroencephalographic Phenotyping and Biomarker Identification, 
%       Sleep, 2022;, zsac223, https://doi.org/10.1093/sleep/zsac223
%
%**********************************************************************

%*************************
% Handle variable inputs *
%*************************

if nargin<1 || isempty(data) || ~any(isfinite(data),'all')
    error('Data must be non-empty and finite')
end

if nargin<2 || isempty(bl_thresh)
    bl_thresh = [];
end

if nargin<3 || isempty(f_verb)
      f_verb = 0;
end

if nargin<4 || isempty(verb_pref)
     verb_pref = '';
end

if nargin<5 || isempty(f_disp)
    f_disp = false;
end


%****************
% Run watershed *
%****************
if f_verb > 0
    disp([verb_pref 'Running watershed...']);
end



% Run watershed
if isempty(bl_thresh)
    % Run watershed
    Ldata = watershed(-data);
else %EXPERIMENTAL: Threshold the data prior to running
    % set value used to mark regions labels where data should be excluded
    exclusion_val = intmax('uint16');
    
    % Set data below threshold to some high number (flintmax)
    below_thresh_inds = data < bl_thresh';
    data(below_thresh_inds) = flintmax;
    
    % Run watershed
    Ldata = watershed(-data);
    
    % If region contains flintmax, set the region's label to exclusion_val
    for ii = 1:max(Ldata,[],'all','omitnan')
        region_inds = Ldata == ii;
        data_val = max(data(region_inds));
        if data_val == flintmax
            Ldata(region_inds) = exclusion_val;
        end
    end
end

if f_disp
    RGB2 = label2rgb(Ldata, 'jet', 'c', 'shuffle');
    R = squeeze(RGB2(:,:,1));
    G = squeeze(RGB2(:,:,2));
    B = squeeze(RGB2(:,:,3));
    R(~Ldata) = 100;
    G(~Ldata) = 100;
    B(~Ldata) = 100;
    RGB2 = cat(3,R,G,B);
    fh = figure('units','normalized','position',[0.7674    0.3978    0.4007    0.4811]);
    ax = axes(fh);
    imagesc(ax,RGB2);
    axis(ax,'xy');
    title(ax,'Watershed Regions');
end

%*******************************************************
% Label border pixels and determine region adjacencies *
%*******************************************************
if f_verb > 0
    disp([verb_pref 'Labeling watershed borders...']);
end

end


