function outPath = dynamo_seed_index(rootDir)
%DYNAMO_SEED_INDEX  Walk a results root and emit a backfill JSONL index.
%
%   outPath = dynamo_seed_index(rootDir) walks rootDir, classifies the
%   per-subject .mat files it finds, and writes a synthetic
%   <rootDir>/_runs/backfill_<host>_<ts>_pid<pid>.jsonl whose entries
%   carry status="backfill". Subsequent dynamo_index_runs(rootDir) calls
%   then see the seeded entries unioned with any future live runs.
%
%   This is the CLI / headless entrypoint. It composes
%   dynamo_walk_results (pure walker, this folder) with
%   dynamo_seed_index_from_cache (per-subject filename classifier, also
%   this folder). The GUI's regenerateRunIndex menu does the same thing
%   but reuses the cache the Results Browser already built.
%
%   Use this once per pre-existing results tree to generate an initial
%   index; new runs append their own JSONL files automatically via
%   DYNAMORunLogger.
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

    arguments
        rootDir (1,:) char
    end

    if ~isfolder(rootDir)
        error('dynamo_seed_index:NotADirectory', ...
            'rootDir does not exist or is not a directory: %s', rootDir);
    end

    cache = dynamo_walk_results(rootDir);
    outPath = dynamo_seed_index_from_cache(rootDir, cache);
end
