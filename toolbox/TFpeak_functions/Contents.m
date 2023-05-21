% TFPEAK_FUNCTIONS
%
% Files
%   cell2Ldata            - takes rgn matrix and converts to labeled 2D form
%   computeMergeWeights   - determines the weights of directed adjacencies between regions
%   computePeakStatsTable - creates a table of the region properties for the peaks
%   computeTFPeaks        - [Main function] run watershed pipeline to extract time-frequency peaks
%   extractTFPeaks        - determines the peak regions within a spectral topography and extracts a set of features for each
%   filterStatsTable      - gets indices of peaks that pass the BW, duration,
%   Ldata2graph           - label region border pixels and determine region adjacencies.
%   mergeRegions          - updates the pixel lists in rgn and borders and the adjacencies in 
%   mergeWshedSegment     - takes the labeled image, borders, and adjacencies output
%   removeBaseline        - subtract percentile baseline from spectrogram 
%   runSegmentedData      - wrapper that runs 1) baseline subtraction, 2) spectrogram
%   runWatershed          - determines peak regions using matlab watershed function.
%   savePeakStats         - saves peak stats to file(s)
%   segmentData           - takes a full spectrogram and chunks it into separate segments
%   subLidx2FullLidx      - converts linear pixel indices within a subregion of an image into
%   trimWshedRegions      - takes data and regions from peaksWShed and regionsMergeByWeight
