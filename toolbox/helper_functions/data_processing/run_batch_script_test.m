
edf_fpaths = {'/autofs/vast/preraugp/data/rodent_data/gulledge/old/EDFs/A02/A02_D04.edf','/autofs/vast/preraugp/data/rodent_data/gulledge/old/EDFs/A02/A02_D05.edf'};
scoring_fpaths = {'/autofs/vast/preraugp/data/rodent_data/gulledge/old/staging/A02/A02_D04_staging.csv','/autofs/vast/preraugp/data/rodent_data/gulledge/old/staging/A02/A02_D05_staging.csv'};
output_fpath = '/autofs/vast/preraugp/users/ss097/batch_test_output_loc';

batch_script(edf_fpaths,scoring_fpaths,output_fpath,2,1,{'EEG'},'header_lines',1,'time_range',[0,43200]);



