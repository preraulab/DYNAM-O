function [bndry, trim_matr]= extract_peak_bndrys_lunesta(subject_number,schiz_flag,night_number)
% load the bytestream file data to extract bndry, peaks matr, Pixel Values
% etc

% check for eris/martinos
if exist('/data/preraugp', 'dir')
    base='/data';
else
    base='/eris';
end

% path to spectrogram data
fpath_spec='/preraugp/projects/spindle_detection/results/lunesta/estimates/wshed_20180302';

% add bytestream load path
addpath([base '/preraugp/users/prath/projects/Spindle Detection/code/Others']);

subject_number_s=sprintf('%02d',subject_number);

if schiz_flag==0
    pre_fname='Lun';
else
    pre_fname='LunS';
end

% load the peaks information
disp('extracting bndry...');
bndry=bytestream_load(fullfile(base,fpath_spec,[pre_fname,subject_number_s,...
    '-Night',num2str(night_number),'_C3_trim_bndry.mat'])); % bndry

disp('extracting peaks matrix...');
trim_matr=bytestream_load(fullfile(base,fpath_spec,[pre_fname,subject_number_s,...
    '-Night',num2str(night_number),'_C3_trim_matr.mat'])); % peaks_matr

end