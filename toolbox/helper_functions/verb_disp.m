function tic_h = verb_disp(verbose, message)
    if verbose
        disp(message)
    end
    if nargout > 0
        tic_h = tic;
    end
end