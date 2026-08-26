# Tooling

The shared build, dist and release tooling of the FuguBSD repositories.

One canonical copy of every shared tool lives here. A consumer repository
references the composite actions and the reusable workflows at `@main`, and it
holds verbatim copies of the synced files. A CI drift gate verifies the copies.
Each consumer describes its own identity in one `.toolingrc` file at its root.

A bad push here breaks the next CI run of every consumer. Run `make check`
before every commit. The specification in [spec/](spec/index.md) states the
contracts.

## Layout

- `org/sync/` — files synced verbatim into every consumer: the make interface,
  the instruction files, the scripts, the skills, and the shared dotfiles
- `perl/sync/` — files synced into the Perl consumers
- `infra/sync/`, `web/sync/`, `python/sync/` — files synced into the consumers
  with OpenTofu code, a fuguweb site, or Python code
- `GNUmakefile`, `mk/` — the root copies of the dispatcher and the fragments
- `actions/`, `perl/actions/`, `python/actions/` — the composite actions
- `.github/workflows/` — the reusable workflows: `perl-build.yml`,
  `perl-release.yml`, and `web-publish.yml`
- `scripts/sync` — copies the selected packs into a consumer; `--check` is the
  CI drift gate
- `perl/t/` — the tests of the canonical tooling

## Consumer usage

From a consumer repository root, with this repository as a sibling checkout:

    ../Tooling/scripts/sync           # copy the shared files in
    ../Tooling/scripts/sync --check   # report drift, change nothing

A consumer selects its packs with `sync.pack` lines in `.toolingrc`: every
consumer takes `org`, a Perl repository adds `perl`, a repository with OpenTofu
code adds `infra`, a repository with a fuguweb site adds `web`, and a repository
with Python code adds `python`. A consumer's `check.yml` runs the same `--check`
as a drift gate. A consumer's `release.yml`, `build.yml`, and `publish.yml` are
thin callers of the reusable workflows.

## Commands

    make deps-test   # install Perl::Critic and Perl::Tidy
    make setup       # install the development tools into .venv
    make check       # lint + format + test + spec-check + ste-lint + lock-py
    make format-md   # Markdown/JSON/YAML formatting
    prove -l perl/t/sync.t   # one test file

The python gates run uv. The operator installs uv, for example from Homebrew. No
deps manifest provides it.

## Commit scopes

`sync`, `deps`, `dist`, `ftp`, `spec-check`, `ste-lint`, `actions`, `workflows`,
`org`, `perl`, `python`, `spec`.

## License

ISC. See [LICENSE](LICENSE).
