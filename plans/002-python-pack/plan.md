# 002 — The python pack

## Status

Proposal. The pack waits on human approval of this plan. When the plan merges,
one change in this repository forms the pack. The adoption is separate work in
each consumer: FuguTTX moves its Python targets out of `mk/local.mk`, and
FuguSTX and FuguCTX create their uv projects. Nothing here blocks the perl pack
or the infra pack.

## Purpose

Three consumers do model-side work in Python. FuguTTX D7 fixes the language:
"Python for all model-side work." FuguTTX REP-TOOLS fixes the tools: Python
3.12, a uv workspace, one lockfile, and Ruff. FuguSTX and FuguCTX rehearse the
FuguTTX pipeline, and each one builds a data pipeline and a tier T0 score script
as its next work. FuguSTX T7 and FuguCTX C8 fix Perl for the engine harness
only. The training-side code of all three repositories is Python.

FuguTTX holds the Python toolchain in its `mk/local.mk` today, with this header:
"The Python targets live here until a second Python repository exists and a
python pack forms." The second and the third repository now exist. This plan
forms the pack, so the three consumers share one toolchain, one Ruff
configuration, and one CI setup action.

## Constraints that shape the pack

- **No identity in a synced file**
  ([SYNC-IDENTITY](../../spec/sync.md#sync-identity), D-02). `pyproject.toml`
  names the consumer, so the pack must not ship it. The pack ships `ruff.toml`,
  and the consumer keeps `pyproject.toml`, `.python-version`, and `uv.lock`.
  Ruff reads `ruff.toml` before the `[tool.ruff]` section, so the adoption
  deletes that section.
- **One path, one pack** ([SYNC-PACKS](../../spec/sync.md#sync-packs)-5). The
  org pack owns `.gitignore`, and it already holds the Python patterns. The
  python pack must not hold the path.
- **The consumer owns `mk/local.mk`** ([MK-LOCAL](../../spec/make.md#mk-local)).
  The FuguTTX adoption deletes its Python targets there, or `make` defines each
  target twice.
- **The include list is fixed**
  ([MK-DISPATCH](../../spec/make.md#mk-dispatch)-2). The list gains
  `mk/python.mk`, after `mk/perl.mk`. The dispatcher is an org file, so the line
  reaches every consumer. `-include` keeps a consumer without the pack green,
  and [make.t](../../perl/t/make.t) proves it.
- **Verb plus language** ([MK-COMPOSE](../../spec/make.md#mk-compose)-2). The
  targets are `lock-py`, `lint-py`, `format-py`, and `format-py-fix`, as the
  FuguTTX hook names them today.
- **No third-party action** ([WFL-ACTIONS](../../spec/workflows.md#wfl-actions),
  D-04). `astral-sh/setup-uv` stays out. A FuguBSD composite action installs a
  pinned uv release tarball, as the FuguTTX workflow does inline today.
- **A root copy of each fragment**
  ([SYNC-CHECK](../../spec/sync.md#sync-check)-4). The root of this repository
  gains `mk/python.mk`.

## The pack contents

| File                                 | Content                                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `python/sync/ruff.toml`              | The shared lint and format configuration: `target-version = "py312"`, `line-length = 100`. Today this lives in the FuguTTX `pyproject.toml` |
| `python/sync/mk/python.mk`           | The make fragment; see below                                                                                                                |
| `python/sync/packages/CLAUDE.md`     | The Python style rules, the analogue of the perl `lib/CLAUDE.md`: Python 3.12, a uv workspace under `packages/`, Ruff clean, pytest         |
| `python/actions/setup-uv/action.yml` | Composite, not synced. It installs a pinned uv from its release tarball, restores `.venv/` from the cache, and runs `uv sync`               |

The fragment generalizes the FuguTTX `mk/local.mk` verbatim:

```make
UV			?= uv

CHECK_TARGETS		+= lock-py
LINT_TARGETS		+= lint-py
FORMAT_TARGETS		+= format-py
FORMAT_FIX_TARGETS	+= format-py-fix

setup:
	$(UV) sync
lock-py:
	$(UV) lock --check
lint-py:
	$(UV) run ruff check .
format-py:
	$(UV) run ruff format --check .
format-py-fix:
	$(UV) run ruff format .
	$(UV) run ruff check --fix .
.PHONY: setup lock-py lint-py format-py format-py-fix
```

The action follows the setup-perl shape: a fail-closed input check, one cache
key computed in one step, `actions/cache/restore@v4` with a prefix, an
unconditional `uv sync`, and `actions/cache/save@v4` on a miss only. The key
hashes `uv.lock`, `.python-version`, `pyproject.toml`, and the uv version. The
consumer reference is `FuguBSD/Tooling/python/actions/setup-uv@main`.

## Files

| File                                  | Change                                                         |
| ------------------------------------- | -------------------------------------------------------------- |
| `scripts/sync`                        | `%PACKS` gains `python => python/sync`                         |
| `python/sync/*`, `python/actions/*`   | New, per the table above                                       |
| `org/sync/GNUmakefile`, `GNUmakefile` | The include list gains `-include mk/python.mk`                 |
| `mk/python.mk`                        | The root copy of the fragment                                  |
| `spec/sync.md`                        | A SYNC-PACKS rule names the pack, its directory, its consumers |
| `spec/make.md`                        | MK-DISPATCH-2 gains `mk/python.mk`; the fragment gets its unit |
| `spec/workflows.md`                   | A cache unit for setup-uv, the analogue of WFL-CACHE           |
| `spec/STATUS.md`                      | The register rows of the touched units, in the same change     |
| `perl/t/sync.t`                       | A python-pack delivery block, the analogue of the infra block  |
| `perl/t/make.t`                       | The fragment joins the scanner, and the include-list assertion |
| `perl/t/org.t`                        | The root-copy check covers `mk/python.mk`                      |
| `perl/t/setup-uv.t`                   | The cache-key test, the analogue of `setup-perl.t`             |
| `README.md`                           | The commit scope `python`                                      |

The adoption in each consumer is separate work: a `sync.pack python` line, a
sync run, and the consumer-side deletions that the constraints above name.

## Tests

- `sync.t` proves the delivery of each pack file, and the drift kinds.
- `make.t` proves the fragment passes the portable subset, every target is in
  `.PHONY`, and an org-only consumer stays green with the new include line.
- `org.t` proves the root copy equals the canon.
- `setup-uv.t` proves the cache key parts, per the workflows specification.

## Open questions

1. **pytest.** No consumer holds a Python test today, and `uv run pytest` fails
   on an empty tree. Does `test-py` join the fragment now, or when the first
   test lands?
2. **The `packages/` path.** The `CLAUDE.md` path fixes the uv-workspace layout
   of FuguTTX REP-LAYOUT for every consumer. FuguSTX and FuguCTX have no layout
   unit yet. Is that the intent?
3. **The uv pin.** The action defaults to one uv version (0.8.17 today, from the
   FuguTTX workflow). Who bumps the default, and does a consumer override it
   with an input?
4. **uv on a dev machine.** The deps manifest `bin` type can install uv with a
   literal URL per platform file, as `scw` installs today. Does each consumer
   add that line, or does the operator install uv by hand?
