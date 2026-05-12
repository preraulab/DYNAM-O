function validate_dpss_mex()
%VALIDATE_DPSS_MEX  Parity gate: dpss_rust_mex vs MATLAB R2025a dpss(N, NW, K).
%
%   Two canonical configs:
%     (N=128, NW=2.0, K=3)   — tolerance 1e-9 elementwise
%     (N=1024, NW=4.0, K=7)  — tolerance 1e-8 elementwise (faer rotation
%                              drift; matches the upstream multitaper_rs
%                              gate at tests/dpss_parity.rs in the
%                              preraulab/multitaper_toolbox PR.)
%
%   Sign-flips are aligned per-taper before comparison (scipy/MATLAB
%   convention: even-indexed tapers have positive sum; odd-indexed have
%   positive central derivative — the same convention both Rust and
%   MATLAB use; we just need to handle the f64 round-off case where the
%   sum is near zero and the implementations pick opposite signs).

    cfgs = {struct('n', 128, 'nw', 2.0, 'k', 3, 'tol_t', 1e-9, 'tol_r', 1e-9), ...
            struct('n', 1024, 'nw', 4.0, 'k', 7, 'tol_t', 1e-8, 'tol_r', 1e-9)};

    fail = false;
    for ci = 1:numel(cfgs)
        c = cfgs{ci};

        [E_mat, V_mat] = dpss(c.n, c.nw, c.k);          % (N, K), (K,)
        [E_rs, V_rs]   = dpss_rust_mex(c.n, c.nw, c.k); % (N, K), (K, 1)

        assert(isequal(size(E_mat), size(E_rs)), ...
            'taper size mismatch: matlab=[%s], rust=[%s]', ...
            num2str(size(E_mat)), num2str(size(E_rs)));
        assert(isequal(size(V_mat(:)), size(V_rs(:))), ...
            'ratio size mismatch');

        % Per-taper sign alignment: if dot(matlab, rust) < 0, flip rust.
        for k = 1:c.k
            if dot(E_mat(:, k), E_rs(:, k)) < 0
                E_rs(:, k) = -E_rs(:, k);
            end
        end

        dt = max(abs(E_mat(:) - E_rs(:)));
        dr = max(abs(V_mat(:) - V_rs(:)));

        ok_t = dt < c.tol_t;
        ok_r = dr < c.tol_r;
        status = '';
        if ok_t && ok_r
            status = 'PASS';
        else
            status = 'FAIL';
            fail = true;
        end
        fprintf('  dpss(n=%4d, nw=%g, k=%d) : tapers=%.2e (tol %.0e), ratios=%.2e (tol %.0e)  %s\n', ...
            c.n, c.nw, c.k, dt, c.tol_t, dr, c.tol_r, status);
    end

    if fail
        error('validate_dpss_mex:fail', 'One or more dpss configs exceeded tolerance.');
    else
        fprintf('All DPSS configs within tolerance.\n');
    end
end
