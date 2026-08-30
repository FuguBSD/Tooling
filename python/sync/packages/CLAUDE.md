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

## Coding style

- Ruff enforces the lint rules and the format. The shared configuration is
  `ruff.toml`, synced from FuguBSD/Tooling. Run `make format-fix` rather than
  hand-formatting.
- `pyproject.toml` must not hold a `[tool.ruff]` section. Ruff prefers
  `ruff.toml`, and a second configuration drifts in silence.
- Give a type hint to each public function signature.
- Prefer the standard library over a dependency where it suffices.

## Testing

- Tests use pytest. The shared fragment defines no `test-py` target, because
  `uv run pytest` fails on an empty tree.
- A test skips gracefully when a dependency is unavailable. Mirror an existing
  test when adding one.
