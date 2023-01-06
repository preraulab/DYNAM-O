function gridfill = binary_gridfill(inds, gridsize)

gridfill = zeros(gridsize);

gridfill(inds) = 1;

end