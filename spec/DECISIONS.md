# Decisions

This document holds the decisions that govern Tooling. A plan must not go
against a decision. To change a decision, propose the change and get human
approval first.

| ID   | Decision                                                                                                                            | Rationale                                                                                           |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| D-01 | One canonical copy of every shared file lives in this repository. A consumer holds a verbatim copy, and `sync --check` verifies it. | A verified copy cannot drift in silence.                                                            |
| D-02 | A synced file must not carry repository identity. Identity lives in the consumer `.toolingrc` and README.                           | One file can then serve every consumer byte for byte.                                               |
| D-03 | Bootstrap scripts use core modules and `use v5.34` only.                                                                            | They run before any install, and macOS ships perl 5.34.                                             |
| D-04 | CI uses no third-party action. GitHub's own `actions/`, this repository's actions, and local paths are the whole allowed set.       | A third-party action is unaudited code with access to the repository.                               |
| D-05 | A reusable workflow references actions by full `FuguBSD/Tooling/...@main` paths.                                                    | The workspace holds the caller's checkout, so a local path resolves in the wrong repository.        |
| D-06 | `environment: release` stays in the callee job. `permissions` and `secrets: inherit` stay in the caller.                            | GitHub applies environment gates in the job that names them, and secrets pass only from the caller. |
