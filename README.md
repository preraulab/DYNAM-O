# Toolbox Development - Watershed TFpeaks and SO-power/phase Histograms

### This is the repository for development and optimization of the watershed algorithm and SOpower/phase histogram computations. The code here is updated and optimized off of the code used in the following publication: 
> 
--- 

* This branch is for development of optimization based on changes to the edge graphs during the merging process:
 - Don't make it a digraph (unidirectional)
 - Fix the overall graph representation and have real merges. I tried this in the past but the matlab graph implementation is very slow.
