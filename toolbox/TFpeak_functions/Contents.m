% TFPEAK_FUNCTIONS
%
% Files
%   cell2Ldata            - Convert region pixel indices to a labeled 2D image
%   computeMergeWeights   - Determine directed adjacency weights between regions
%   computePeakSOphase    - Compute the slow-oscillation phase for each TF peak
%   computePeakSOpower    - Compute the slow-oscillation power for each TF peak
%   computePeakStage      - Compute the sleep stage for each TF peak
%   computePeakStatsTable - Create a table of region properties for detected peaks
%
%   computeTFPeaks        - Run the watershed pipeline to extract time-frequency peaks
%
%   displaySummaryPlot    - Display the main outputs of runDYNAMO
%   displayTFPeaks        - Display detected TF peaks overlaid on a spectrogram
%   extractTFPeaks        - Determine peak regions in a spectrogram and extract their features
%   filterStatsTable      - Select TF peaks by duration, bandwidth, frequency, and height
%   Ldata2graph           - Label region borders and build the region adjacency list
%   mergeRegions          - Merge regions and update borders, adjacency, and weight flags
%   mergeWshedSegment     - Merge watershed regions iteratively under a merge rule
%   refinePeakFrequency   - Refine peak frequencies using a 1-Hz-resolution Hann spectrogram
%   removeBaseline        - Subtract a percentile baseline from a spectrogram
%   runSegmentedData      - Segment, extract, and compile TF peaks from a spectrogram
%   runWatershed          - Determine peak regions using MATLAB's watershed function
%   savePeakStats         - Save peak statistics to files
%   segmentData           - Chunk a spectrogram into fixed-duration segments
%   subLidx2FullLidx      - Convert subregion linear indices to full-image indices
%   trimWshedRegions      - Trim watershed regions to a target fraction of volume
%
% Folders
%   option_sets           - Build DYNAM-O option sets and configure MATLAB parallel pools
