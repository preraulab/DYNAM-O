function runApp()
%RUNAPP  Launch the DYNAM-O GUI (DYNAMOFileManager).
%
%   Calls init_DYNAMO('clear','gui') to reset the class cache and add
%   both the toolbox and GUI trees to the path, then opens the
%   file-manager window. This is the canonical entrypoint for the
%   desktop application and the natural mcc -m compile target.
%
%   The 'clear' flag evicts only DYNAM-O class definitions so a stale
%   class cached from a shadowing copy elsewhere on the path — e.g. an
%   old CSSuiTable from a sibling repo loaded earlier in the session —
%   cannot persist into the new GUI. Third-party classes,
%   base-workspace variables, and breakpoints from other tools are
%   left alone. Live DYNAM-O instances (an already-open file manager)
%   will be cleared along with the cache.

    init_DYNAMO('clear', 'gui');
    DYNAMOFileManager();
end
