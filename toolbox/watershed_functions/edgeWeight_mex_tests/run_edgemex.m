load edge_test_data.mat

tic
e = edgeWeight(bnds_ii,rgn_jj,data);
toc

tic
e = edgeWeight_mex(bnds_ii,rgn_jj,data);
toc
