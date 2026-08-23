# The make interface

Every repository serves one standard make interface: the generic verbs, the
composition contract, and the dispatchers. The org pack distributes the GNU
dispatcher and the org fragment. The perl pack distributes the Perl fragment.
This document specifies the vocabulary, the composition, the dispatchers, the
portable subset, and the consumer hook.

<a id="mk-verbs"></a>

## The target vocabulary

- **MK-VERBS-1** — A `<verb>` target must read and must not write. A
  `<verb>-fix` target writes the change that its verb reports. A verb without a
  fixer must not have a `-fix` target.
- **MK-VERBS-2** — Every consumer must serve the generic verbs `check`, `lint`,
  `format`, `format-fix`, and `test`.
- **MK-VERBS-3** — `check` must run every read-only gate of the repository. It
  is the commit gate.
- **MK-VERBS-4** — The target names `deps`, `deps-test`, and `deps-develop` must
  not change. The setup-perl action computes them from its `dependencies` input.
- **MK-VERBS-5** — `format-md` must not join an aggregate. prettier runs through
  npx, no deps manifest provides node, and CI runs the target in its own job.

`spec-check`, `ste-lint`, and `dist` keep their names as plain targets.

<a id="mk-compose"></a>

## Composition

A fragment appends namespaced targets to aggregation variables, and the
dispatcher aggregates them into the verbs.

- **MK-COMPOSE-1** — A fragment must append its targets to the aggregation
  variables `CHECK_TARGETS`, `LINT_TARGETS`, `FORMAT_TARGETS`, and
  `FORMAT_FIX_TARGETS`.
- **MK-COMPOSE-2** — A sub-target name must join the verb and the language, for
  example `lint-perl` and `format-perl-fix`.
- **MK-COMPOSE-3** — The aggregate rules must sit after every include, because
  make expands a prerequisite list at read time.
- **MK-COMPOSE-4** — A fragment must give each variable default with `?=`, so
  the consumer hook wins.

### Variables

`mk/org.mk` defines `SPEC_CHECK`, `STE_LINT`, `PRETTIER`, `PROVE`, and
`TEST_GLOBS`. `mk/perl.mk` defines `PERL_SRC_DIRS`, `DEPS`, `DIST`, and
`VERSION`. The `VERSION` default is empty, and `scripts/dist` treats an empty
value as absent.

<a id="mk-dispatch"></a>

## The dispatchers

A dispatcher holds the include chain and the generic verbs, and nothing else.

```make
# GNUmakefile: canonical copy, owned by FuguBSD/Tooling.
-include mk/local.mk
include mk/org.mk
-include mk/perl.mk

check: $(CHECK_TARGETS)
lint: $(LINT_TARGETS)
format: $(FORMAT_TARGETS)
format-fix: $(FORMAT_FIX_TARGETS)
.PHONY: check lint format format-fix
```

- **MK-DISPATCH-1** — The org pack must own the GNU dispatcher `GNUmakefile`.
- **MK-DISPATCH-2** — The include list must be fixed, in this order:
  `mk/local.mk`, `mk/org.mk`, `mk/perl.mk`. A dispatcher must not use a glob.
- **MK-DISPATCH-3** — Only a dispatcher can use dialect-specific syntax.
- **MK-DISPATCH-4** — The BSD dispatcher `Makefile` must mirror the GNU
  dispatcher with `.include` lines, for OpenBSD base make. The path `Makefile`
  must stay free for it in every consumer.

GNU make prefers a `GNUmakefile` when both files exist, and BSD make reads
`Makefile`. The two dispatchers therefore serve both dialects side by side.

<a id="mk-subset"></a>

## The portable subset

- **MK-SUBSET-1** — A fragment must use only the assignments `=`, `?=`, and
  `+=`, variable references, rule lines, recipe lines, and `.PHONY`.
- **MK-SUBSET-2** — A fragment must not use a conditional, a GNU function, or a
  BSD variable modifier.
- **MK-SUBSET-3** — Logic must live in the scripts. A fragment must not compute
  at parse time.

The subset is the part that the GNU and BSD make dialects share. A fragment that
satisfies it serves every dispatcher without change.

<a id="mk-local"></a>

## The consumer hook

- **MK-LOCAL-1** — `mk/local.mk` belongs to the consumer. No pack may hold the
  path, and sync must not touch it.
- **MK-LOCAL-2** — The file must hold the build variables and the repo-only
  targets of the consumer, and nothing else.

`.toolingrc` stays the identity home of the synced scripts. The two homes hold
different facts: `dist.testdir` names the dist test set, and `TEST_GLOBS` names
the full tier set of `make test`.
