# Tooling

> **CRITICAL: Write all output and all artifacts in ASD-STE100 Simplified
> Technical English.** This rule applies to the README, code comments, commit
> messages, and chat replies. Use the active voice and the approved words. Keep
> each instruction shorter than 20 words and each descriptive sentence shorter
> than 25 words. Write one instruction in each sentence. Do not change technical
> names, commands, or code examples.

The shared build, dist and release tooling of the FuguBSD repositories. Every
consumer depends on this repository at `@main`: a bad push here breaks every
consumer's next CI run. The tests under `perl/t/` are the guard — run
`make check` before every commit.

## Rules

- One canonical copy. A file under `perl/sync/` is the truth; the copies in the
  consumers are verified by `scripts/sync --check`.
- The synced scripts carry no repository identity. Identity lives in each
  consumer's `.toolingrc` (namespaced keys, e.g. `dist.name`).
- Bootstrap scripts (`perl/sync/scripts/deps`, `scripts/sync`) use core modules
  and `use v5.34` only — they run before anything is installed, and macOS still
  ships perl 5.34. Everything else uses `use v5.36`.
- `perl/sync/scripts/deps` finds `ftp` as an executable sibling. The two files
  move together, and the exec bit matters.
- No third-party action: GitHub's own `actions/`, this organization's, or a
  local path. `perl/t/setup-perl.t` enforces it.
- Reusable workflows live flat in `.github/workflows/` with a language prefix
  (`perl-*.yml`). Inside them, reference actions by full
  `FuguBSD/Tooling/...@main` paths, never `./` — the workspace holds the
  caller's checkout.
- `environment: release` stays in the callee job; `permissions` and
  `secrets: inherit` stay in the caller. Do not move them.
- The setup-perl cache key hashes `deps/Linux.txt`, `scripts/deps` and
  `perl/sync/scripts/deps`. Keep `perl/t/setup-perl.t` in sync with any change.
- OpenBSD style(9) Perl, ISC license, conventional commits.

## Extending to a new language scope

Create `<lang>/` with the same shape: `<lang>/actions/`, `<lang>/sync/`,
`<lang>/t/`. Add reusable workflows as `.github/workflows/<lang>-*.yml`. Teach
`scripts/sync` the new sync root only when the first consumer exists.

## Commands

```sh
make deps-test   # install Perl::Critic and Perl::Tidy
make check       # lint + test + tidy; MUST pass before every commit
make prettier    # Markdown/JSON/YAML formatting check
prove -l perl/t/dist.t   # one test file
```
