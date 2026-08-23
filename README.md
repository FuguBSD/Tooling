# Tooling

The shared build, dist and release tooling of the FuguBSD repositories.

One canonical copy of every shared tool lives here. A consumer repository uses
the tooling in two ways: it references the composite actions and the reusable
workflows across repositories at `@main`, and it holds verbatim copies of the
synced files, verified by a CI drift gate. Each consumer describes its own
identity in one `.toolingrc` file at its root.

A bad push here breaks the next CI run of every consumer. Run `make check`
before every commit. The specification in [spec/](spec/index.md) states the
contracts.

## Layout

- `org/sync/` — files synced verbatim into every consumer: the instruction
  files, `scripts/{deps,ftp,spec-check,ste-lint}`, `t/ci/workflows.t`, the
  review-panel skill, the pull-request template, and `.prettierrc`
- `perl/sync/` — files synced into the Perl consumers: `scripts/dist`,
  `lib/CLAUDE.md`, `.perlcriticrc`, and `.perltidyrc`
- `actions/` — language-neutral composite actions (`gh-release`)
- `perl/actions/` — Perl composite actions (`setup-perl`, `pause-upload`)
- `perl/t/` — the tests of the canonical tooling
- `scripts/sync` — copies the selected packs into a consumer; `--check` is the
  CI drift gate
- `.github/workflows/perl-build.yml`, `perl-release.yml` — reusable workflows
  that the Perl consumers call
- `.github/workflows/web-publish.yml` — reusable workflow that builds the
  FuguWeb site of a consumer and deploys it to GitHub Pages

## Consumer usage

From a consumer repository root, with this repository as a sibling checkout:

    ../Tooling/scripts/sync           # copy the shared files in
    ../Tooling/scripts/sync --check   # report drift, change nothing

A consumer selects its packs with `sync.pack` lines in `.toolingrc`: every
consumer takes `org`, and a Perl repository adds `perl`. A consumer's
`check.yml` runs the same `--check` as a drift gate. A consumer's `release.yml`,
`build.yml`, and `publish.yml` are thin callers of the reusable workflows.

## Commands

    make deps-test   # install Perl::Critic and Perl::Tidy
    make check       # lint + test + tidy + spec-check + ste-lint
    make prettier    # Markdown/JSON/YAML formatting
    prove -l perl/t/sync.t   # one test file

## Commit scopes

`sync`, `deps`, `dist`, `ftp`, `spec-check`, `ste-lint`, `actions`, `workflows`,
`org`, `perl`, `spec`.

## License

ISC. See [LICENSE](LICENSE).
