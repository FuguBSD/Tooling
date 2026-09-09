# Tooling

The shared build, dist, release and agent tooling of the FuguBSD repositories.
One canonical copy of every shared tool lives here. A consumer references the
actions and the reusable workflows at `@main`, and holds verbatim copies of the
synced files. A CI drift gate verifies the copies.

A consumer selects its packs in one `.toolingrc` at its root, and `scripts/sync`
copies the packs in. A bad push here breaks the next CI run of every consumer,
so run `make check` before every commit. The specification in
[spec/](spec/index.md) states the contracts.

## Commands

```sh
make deps-test   # install Perl::Critic and Perl::Tidy
make setup       # install the development tools into .venv
make check       # run every gate; run it before each commit
make test        # run the tests of the canonical tooling
make format-fix  # fix the Perl, Python, Markdown, JSON and YAML formatting
```

## Commit scopes

`sync`, `deps`, `dist`, `ftp`, `spec-check`, `ste-lint`, `actions`, `workflows`,
`org`, `perl`, `python`, `spec`.
