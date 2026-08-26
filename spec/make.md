# The make interface

Every repository serves one standard make interface: the generic verbs, the
composition contract, and the dispatchers. The org pack distributes the GNU
dispatcher and the org fragment. The perl pack distributes the Perl fragment,
and the python pack distributes the python fragment. This document specifies the
vocabulary, the composition, the dispatchers, the portable subset, the python
fragment, and the consumer hook.

<a id="mk-verbs"></a>

## The target vocabulary

- **MK-VERBS-1** — Every target of the interface must read and must not write.
  The exceptions are the `-fix` targets, `dist`, `setup`, and the `deps`
  targets. A `-fix` target writes the change that its paired target reports.
  Every `-fix` target must pair with the read-only target of the same base name.
  The rule covers the targets that the dispatcher and the fragments define. The
  rule covers the tracked files: a target can write a gitignored cache or
  environment, for example `.ruff_cache/` or `.venv/`.
- **MK-VERBS-2** — Every consumer must serve the generic verbs `check`, `lint`,
  `format`, `format-fix`, and `test`.
- **MK-VERBS-3** — `check` must run every read-only gate of the repository. It
  is the commit gate.
- **MK-VERBS-4** — The target names `deps`, `deps-test`, and `deps-develop` must
  not change. `mk/org.mk` must define the three targets over `$(DEPS)`, because
  the org pack ships `scripts/deps`. The setup-perl action computes the names
  from its `dependencies` input.
- **MK-VERBS-5** — `format-md` must join `FORMAT_TARGETS`, and `format-md-fix`
  must join `FORMAT_FIX_TARGETS`. Only `mk/org.mk` defines the pair. prettier
  runs through bunx: the operator installs bun, and a CI job runs the setup-bun
  action before a format gate. No deps manifest provides bun.

`all`, `setup`, `spec-check`, `ste-lint`, `dist`, and the `deps` targets are
plain targets, not verbs.

<a id="mk-compose"></a>

## Composition

A fragment appends namespaced targets to aggregation variables, and the
dispatcher aggregates them into the verbs.

- **MK-COMPOSE-1** — The language aggregation variables are `LINT_TARGETS`,
  `FORMAT_TARGETS`, `FORMAT_FIX_TARGETS`, and `TEST_TARGETS`. A fragment must
  append each of its namespaced targets to the variable of its verb.
- **MK-COMPOSE-2** — A namespaced target must join its verb and the language or
  the tool, with `-fix` last. Examples: `lint-perl` serves `lint`, and
  `format-perl-fix` serves `format-fix`.
- **MK-COMPOSE-3** — The aggregate rules must sit after every include, because
  make expands a prerequisite list at read time.
- **MK-COMPOSE-4** — A fragment must give a configuration variable its default
  with `?=`, so the consumer hook wins. A fragment must append to an aggregation
  variable with `+=`.
- **MK-COMPOSE-5** — `CHECK_TARGETS` is the gate list of `check`. `mk/org.mk`
  must append `lint`, `format`, `test`, `spec-check`, and `ste-lint` to it, per
  MK-VERBS-3. `mk/local.mk` can append a repo-only gate, and a language fragment
  can append a language gate, for example `lock-py`.
- **MK-COMPOSE-6** — A fragment must declare each of its targets in `.PHONY`. A
  target name can equal a directory name, for example `deps`, and a phony target
  runs anyway.

### Variables

`mk/org.mk` defines `SPEC_CHECK`, `STE_LINT`, `DEPS`, `PRETTIER`, `PROVE`, and
`TEST_GLOBS`. `mk/perl.mk` defines `PERL_SRC_DIRS`, `PERLTIDY`, `DIST`, and
`VERSION`. The `VERSION` default is empty, and `scripts/dist` treats an empty
value as absent. `mk/python.mk` defines `UV`.

<a id="mk-dispatch"></a>

## The dispatchers

A dispatcher holds the default goal, the include chain, and the generic verbs,
and nothing else.

```make
# The org pack of FuguBSD/Tooling owns this file. Do not edit a
# synced copy. Edit the canonical copy in FuguBSD/Tooling.

all: check

-include mk/local.mk
include mk/org.mk
-include mk/perl.mk
-include mk/python.mk

check: $(CHECK_TARGETS)
lint: $(LINT_TARGETS)
format: $(FORMAT_TARGETS)
format-fix: $(FORMAT_FIX_TARGETS)
test: $(TEST_TARGETS)
.PHONY: all check lint format format-fix test
```

- **MK-DISPATCH-1** — The org pack must own the GNU dispatcher `GNUmakefile`.
- **MK-DISPATCH-2** — The include list must be fixed, in this order:
  `mk/local.mk`, `mk/org.mk`, `mk/perl.mk`, `mk/python.mk`. A dispatcher must
  not use a glob.
- **MK-DISPATCH-3** — Only a dispatcher can use dialect-specific syntax.
- **MK-DISPATCH-4** — The BSD dispatcher `Makefile` must mirror the GNU
  dispatcher for OpenBSD base make. It must use `.include` for a required file
  and `.sinclude` for an optional file. The path `Makefile` must stay free for
  it in every consumer.
- **MK-DISPATCH-5** — The first rule of a dispatcher must be `all: check`. Bare
  `make` then runs the commit gate in every consumer.

GNU make prefers a `GNUmakefile` when both files exist, and BSD make reads
`Makefile`. The two dispatchers therefore serve both dialects side by side.

<a id="mk-subset"></a>

## The portable subset

- **MK-SUBSET-1** — A fragment must use only blank lines, comment lines, the
  assignments `=`, `?=`, and `+=`, variable references, rule lines, recipe
  lines, and `.PHONY`.
- **MK-SUBSET-2** — A fragment must not use a conditional, a GNU function, or a
  BSD variable modifier.
- **MK-SUBSET-3** — Logic must live in the scripts. A fragment must not compute
  at parse time.

The subset is the part that the GNU and BSD make dialects share. A fragment that
satisfies it serves every dispatcher without change.

<a id="mk-python"></a>

## The python fragment

- **MK-PYTHON-1** — `mk/python.mk` must define `setup`, `lock-py`, `lint-py`,
  `format-py`, and `format-py-fix` over uv and Ruff, per MK-COMPOSE.
- **MK-PYTHON-2** — The consumer must hold `pyproject.toml`, `.python-version`,
  and `uv.lock`. The pack must not ship them, per SYNC-IDENTITY. A dependency
  group of the consumer must hold Ruff, so `uv run` finds the locked release,
  never a `PATH` fallback.
- **MK-PYTHON-3** — A consumer `pyproject.toml` must not hold a `[tool.ruff]`
  section. Ruff prefers the synced `ruff.toml`, and a second configuration
  drifts in silence.
- **MK-PYTHON-4** — The synced test `t/ci/python.t` must enforce MK-PYTHON-2 and
  MK-PYTHON-3 in every consumer.

<a id="mk-local"></a>

## The consumer hook

- **MK-LOCAL-1** — `mk/local.mk` belongs to the consumer. No pack may hold the
  path, and sync must not touch it.
- **MK-LOCAL-2** — The file must hold the build variables and the repo-only
  targets of the consumer, and nothing else.
- **MK-LOCAL-3** — `mk/local.mk` must satisfy the portable subset of MK-SUBSET.
  Every dispatcher includes the file.
- **MK-LOCAL-4** — `mk/local.mk` must not define a target that a synced fragment
  defines. A second recipe for one target makes make print an override warning.
  The synced test `t/ci/local.t` must enforce the rule in every consumer.

`.toolingrc` stays the identity home of the synced scripts. The two homes hold
different facts: `dist.testdir` names the dist test set, and `TEST_GLOBS` names
the full tier set of `make test`.
