classdef DYNAMORunLogger < handle
    %DYNAMORUNLOGGER  Append-only JSONL writer for batch-run completion events.
    %
    %   One logger per batch invocation. Each writer owns a single file in
    %   <results_root>/_runs/ — concurrent batches on different machines
    %   write to distinct files with no contention. Readers (e.g.
    %   dynamo_index_runs) union the files at read time.
    %
    %
    %   `files` paths are root-relative (under the results root), use
    %   forward slashes regardless of platform, and are derived from
    %   `components` via dynamo_files_for_components. Storing them
    %   exhaustively at write time lets the GUI tree skip the recursive
    %   filesystem walk on subsequent loads — the index becomes the
    %   source of truth for "what's in this results folder".
    %
    %   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

    properties (SetAccess = private)
        Path          = ''
        RunID         = ''
        Host          = ''
        User          = ''
        Pid           = NaN
        CodeVersion   = ''            % dynamo_version() grammar '<semver>+<sha12>[.dirty]'
        Writer        = 'dynamo-matlab'
        KernelVersion = ''            % dynamo_kernel_version() or 'unknown'
        StartTime
    end

    properties (Access = private)
        fid = -1
    end

    methods
        function obj = DYNAMORunLogger(rootDir)
            arguments
                rootDir (1,:) char
            end
            if ~isfolder(rootDir)
                error('DYNAMORunLogger:BadRoot', ...
                    'Results root does not exist: %s', rootDir);
            end
            runsDir = fullfile(rootDir, '_runs');
            if ~isfolder(runsDir), mkdir(runsDir); end

            obj.Host        = DYNAMORunLogger.safeHostname();
            obj.User        = DYNAMORunLogger.safeUser();
            obj.Pid         = double(feature('getpid'));
            obj.StartTime   = datetime('now','TimeZone','UTC');
            ts              = char(datetime(obj.StartTime,'Format','yyyyMMdd_HHmmss'));
            obj.RunID       = sprintf('%s_%s_pid%d', ...
                DYNAMORunLogger.sanitize(obj.Host), ts, obj.Pid);
            obj.CodeVersion = DYNAMORunLogger.detectCodeVersion();
            obj.KernelVersion = DYNAMORunLogger.detectKernelVersion();
            obj.Path        = fullfile(runsDir, [obj.RunID '.jsonl']);

            obj.fid = fopen(obj.Path, 'a');
            if obj.fid < 0
                error('DYNAMORunLogger:OpenFailed', ...
                    'Could not open run log for append: %s', obj.Path);
            end
        end

        function recordSubject(obj, subject, channel, opts)
            %RECORDSUBJECT  Append one (subject, channel) completion event.
            arguments
                obj
                subject (1,:) char
                channel (1,:) char
                opts.InputFile   (1,:) char   = ''
                opts.Components  (1,:) cell   = {}
                opts.Status      (1,:) char   = 'ok'   % ok | partial | skipped | load_failed
                opts.Failures    (1,:) cell   = {}
                opts.DurationSec (1,1) double = NaN
            end
            if obj.fid < 0, return, end

            evt = struct();
            evt.ts            = DYNAMORunLogger.iso8601(datetime('now','TimeZone','UTC'));
            evt.host          = obj.Host;
            evt.user          = obj.User;
            evt.pid           = obj.Pid;
            evt.run_id        = obj.RunID;
            % Provenance stamp keys (OUTPUT_FORMAT.md section 8). The
            % legacy code_version key stays and carries the writer_version
            % value so pre-stamp readers keep working.
            evt.code_version  = obj.CodeVersion;
            evt.writer        = obj.Writer;
            evt.kernel_version = obj.KernelVersion;
            evt.subject       = subject;
            evt.channel       = channel;
            evt.input_file    = opts.InputFile;
            evt.components    = opts.Components;
            evt.files         = dynamo_files_for_components( ...
                                    subject, channel, opts.Components);
            evt.status        = opts.Status;
            evt.failures      = opts.Failures;
            evt.duration_sec  = opts.DurationSec;

            try
                line = jsonencode(evt);
                fprintf(obj.fid, '%s\n', line);
            catch ME
                warning('DYNAMORunLogger:writeFailed', ...
                    'Could not write run-log entry: %s', ME.message);
            end
        end

        function close(obj)
            if obj.fid >= 0
                try, fclose(obj.fid); catch, end %#ok<NOSEMI>
                obj.fid = -1;
            end
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Static, Access = private)
        function s = iso8601(dt)
            s = char(datetime(dt,'Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
        end
        function s = safeHostname()
            s = '';
            try
                [st, out] = system('hostname');
                if st == 0, s = strtrim(out); end
            catch
            end
            if isempty(s), s = getenv('HOSTNAME'); end
            if isempty(s), s = getenv('COMPUTERNAME'); end
            if isempty(s), s = 'unknown_host'; end
        end
        function s = safeUser()
            s = getenv('USER');
            if isempty(s), s = getenv('USERNAME'); end
            if isempty(s), s = 'unknown_user'; end
        end
        function s = sanitize(in)
            s = regexprep(in, '[^A-Za-z0-9_-]', '_');
        end
        function s = detectCodeVersion()
            %DETECTCODEVERSION  Toolbox build in the provenance grammar.
            %   Fail-soft: an empty char when dynamo_version is not on
            %   the path (the logger must never break a batch).
            try
                s = dynamo_version();
            catch
                s = '';
            end
        end
        function s = detectKernelVersion()
            %DETECTKERNELVERSION  Loaded dynamo_rs kernel build identity.
            %   Fail-soft 'unknown' mirrors dynamo_kernel_version's own
            %   fallback so jsonl events always carry the key.
            try
                s = dynamo_kernel_version();
            catch
                s = 'unknown';
            end
        end
    end
end
