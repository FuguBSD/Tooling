# Tooling

The shared build, dist and release tooling of the FuguBSD repositories.

One canonical copy of every shared tool lives here. A consumer repository uses
the tooling in two ways: it references the composite actions and the reusable
workflows across repositories at `@main`, and it holds verbatim copies of the
synced files, verified by a CI drift gate. Each consumer describes its own
identity in one `.toolingrc` file at its root.

The repository is scoped by language: `perl/` serves Fugu, FuguVM and FuguWeb.
Future scopes hold C tooling (FuguOracle, FuguPass) and Python tooling
(FuguTTX).

## Layout

- `actions/` — language-neutral composite actions (`gh-release`)
- `perl/actions/` — Perl composite actions (`setup-perl`, `pause-upload`)
- `perl/sync/` — files synced verbatim into every Perl consumer:
  `scripts/{dist,deps,ftp}`, `t/ci/workflows.t`, and the lint configurations
- `perl/t/` — the tests of the canonical tooling
- `scripts/sync` — copies `perl/sync/` into a consumer; `--check` is the CI
  drift gate
- `.github/workflows/perl-release.yml`, `perl-build.yml` — reusable workflows
  that consumers call

## Consumer usage

From a consumer repository root, with this repository as a sibling checkout:

    ../Tooling/scripts/sync           # copy the shared files in
    ../Tooling/scripts/sync --check   # report drift, change nothing

A consumer's `check.yml` runs the same `--check` as a drift gate. A consumer's
`release.yml` and `build.yml` are thin callers of the reusable workflows.

## Development

    make deps-test   # install Perl::Critic and Perl::Tidy
    make check       # lint + test + tidy
    make prettier    # Markdown/JSON/YAML formatting

See [CLAUDE.md](CLAUDE.md) for the conventions.

## License

ISC. See [LICENSE](LICENSE).
