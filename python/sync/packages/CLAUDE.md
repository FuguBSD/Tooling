<!--
The python pack of FuguBSD/Tooling owns this file. Do not edit a synced
copy. Edit the canonical copy in FuguBSD/Tooling.
-->

# packages/

Applies when working on Python code in this repository.

## Toolchain

- Python 3.12. `.python-version` pins the interpreter.
- uv manages the environment. The packages form one uv workspace under
  `packages/`, with one `uv.lock` at the repository root.
- The operator installs uv, for example from Homebrew or from a release tarball.
  No deps manifest provides it.
- `make setup` installs the development tools into `.venv`.
- `make check` runs the lockfile gate, the Ruff lint, and the Ruff format check.
  Run it before each commit.

## Coding style

- Ruff enforces the lint rules and the format. The shared configuration is
  `ruff.toml`, synced from FuguBSD/Tooling. Run `make format-fix` rather than
  hand-formatting.
- `pyproject.toml` must not hold a `[tool.ruff]` section. Ruff prefers
  `ruff.toml`, and a second configuration drifts in silence.
- Give a type hint to each public function signature.
- Prefer the standard library over a dependency where it suffices.

## Simplicity

- Delete an old code path outright. Never keep an alias, a bridge, or a
  migration.
- Implement an API only for a documented need. A specification unit, in this
  repository or in an other FuguBSD repository, must name the need. Delete a
  function or an option that no specification names, together with its test.
- Validate each input once, at its boundary. Do not check the same invariant
  again downstream.

## Error handling

- Raise an exception for a programming error. Never use an exception for flow
  control.
- Fail cleanly: diagnose invalid input in a human-readable message, never a
  stack trace. Leave no partial file, orphaned process, or corrupt state behind.
  Make repeatable operations truly idempotent.
- Fail closed. Never trust external input.

## Testing

- Tests use pytest. The shared fragment defines no `test-py` target, because
  `uv run pytest` fails on an empty tree.
- A test skips gracefully when a dependency is unavailable. Mirror an existing
  test when adding one.
- Be resilient to timing variations.
- Every feature needs tests.
