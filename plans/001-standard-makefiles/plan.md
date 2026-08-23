# 001 — The standard Makefile of the packs

## Status

Proposed. Implements: MK-VERBS, MK-COMPOSE, MK-DISPATCH, MK-SUBSET, MK-LOCAL.

The cited units are new. Change one adds them to the specification, in a new
document `spec/make.md`, together with the decisions. Change two implements
them, with this repository as the first consumer. Both changes can land now, in
that order. Nothing waits on another repository.

Consumer adoption is the work of each consumer, through its own sync change, and
this plan does not describe it. One sequencing fact applies: after change two,
the drift gate of a consumer stays red until its sync change merges. Adopt the
consumers promptly, in any order.

## Purpose

Tooling distributes one standard root Makefile with standard targets. A language
pack composes its targets into the generic verbs: `make lint`, `make format`,
`make check`. Today every repository hand-writes its root Makefile, and the
target names disagree: `tidy` and `tidy-fix` in the Perl repositories, `fmt` and
`fmt-check` elsewhere. The composition of `check` drifts the same way. A shared
Makefile puts the target contract under the same drift gate that guards the
synced scripts.

## Why Tooling holds this work

The root Makefile is shared tooling. One canonical copy of every shared tool
lives in this repository (D-01), and a consumer holds a verbatim copy that
`sync --check` verifies. The target names are an interface: the workflows, the
shared actions, and the operators call them in every repository. An interface
that every consumer shares lives in the canon.

## The design

### Ownership and layout

- `Makefile` — the org pack. The dispatcher: the include chain and the generic
  verbs, and nothing else.
- `mk/org.mk` — the org pack. The `spec-check`, `ste-lint`, `test`, `format-md`,
  and `format-md-fix` targets.
- `mk/perl.mk` — the perl pack. The `lint-perl`, `format-perl`,
  `format-perl-fix`, `dist`, `deps`, `deps-test`, and `deps-develop` targets.
- `mk/local.mk` — the consumer. Build variables and repo-only targets. No pack
  holds the file, and sync never touches it.

No relative path exists in two packs, per SYNC-PACKS-5. The consumer hook
follows the pattern of the synced `CLAUDE.md` (SYNC-IDENTITY-3): a canonical
shell with one local import.

### The dispatcher

```make
# Makefile: canonical copy, owned by FuguBSD/Tooling.
-include mk/local.mk
include mk/org.mk
-include mk/perl.mk

check: $(CHECK_TARGETS)
lint: $(LINT_TARGETS)
format: $(FORMAT_TARGETS)
format-fix: $(FORMAT_FIX_TARGETS)
.PHONY: check lint format format-fix
```

- The include list is fixed. A glob makes the order and the pickup accidental.
  The pack set is closed, and the dispatcher is the one place that names it.
- `mk/local.mk` loads first, so the consumer sets variables before any fragment
  reads them. A fragment gives its defaults with `?=`.
- The aggregate rules sit at the bottom, after every include. make expands a
  prerequisite list at read time, so the aggregates must read complete lists.
- `-include` stays silent only on a missing file. A missing fragment of a
  selected pack is drift, and the sync gate reports it.

### Composition

A fragment appends namespaced targets to aggregation variables, and it defines
those targets:

```make
# mk/perl.mk
LINT_TARGETS += lint-perl
lint-perl:
	...
```

- The aggregation variables are `CHECK_TARGETS`, `LINT_TARGETS`,
  `FORMAT_TARGETS`, and `FORMAT_FIX_TARGETS`.
- Every sub-target stays addressable, for example `make lint-perl`. CI keeps its
  per-tool jobs through the sub-targets.
- An aggregate is a prerequisite list, so `make -j` runs the sub-targets in
  parallel.

### The vocabulary

A `<verb>` target reads and never writes. A `<verb>-fix` target writes. A verb
without a fixer has no `-fix` target.

- `check` — every read-only gate. The commit gate of every repository.
- `lint` — static analysis.
- `format` — the formatting diff. `format-fix` writes the format.
- `test` — the test tiers, through `prove`.
- `spec-check`, `ste-lint`, `dist` — as today.
- `deps`, `deps-test`, `deps-develop` — frozen names. The shared
  [setup-perl](../../perl/actions/setup-perl/action.yml) action computes these
  names from its `dependencies` input.

`format-md` runs prettier, and it stays out of every aggregate. prettier runs
through npx, and no deps manifest provides node. CI runs `make format-md` in its
own job, as today. The comment that states this reason lives in `mk/org.mk`.

The old writer names die with the adoption: `tidy-fix`, `prettier-fix`, and
`fmt`. No alias remains.

### The portable subset

A fragment uses only the subset that the GNU and BSD make dialects share:

- The assignments `=`, `?=`, and `+=`.
- Variable references, rule lines, recipe lines, and `.PHONY`.
- No conditionals, no GNU functions such as `$(shell)` and `$(wildcard)`, and no
  BSD variable modifiers.
- Logic lives in the scripts, never in make.

The dispatcher holds every dialect-specific line, and it ships in the GNU
dialect. This matches the current Makefiles. A later BSD dispatcher can join
without a fragment change, because GNU make prefers a `GNUmakefile` when both
files exist. That work is out of scope.

One GNU function falls out of the current Makefiles: the version derivation
through `$(shell git describe ...)`. `scripts/dist` already derives the version
when the flag is absent. The fragment therefore passes `--version '$(VERSION)'`
with an empty default, and `scripts/dist` treats an empty value as absent. CI
keeps `make dist VERSION=1.2.3`, so
[perl-release.yml](../../.github/workflows/perl-release.yml) does not change.

### The variables

`mk/org.mk` defines, with `?=` defaults:

- `SPEC_CHECK`, `STE_LINT` — the script invocations, default
  `scripts/spec-check` and `scripts/ste-lint`.
- `PRETTIER` — default `npx prettier@3.9.6`.
- `PROVE`, `TEST_GLOBS` — the test runner and the tiers, default `prove -l` and
  `t/ci/*.t`.

`mk/perl.mk` defines, with `?=` defaults:

- `PERL_SRC_DIRS` — the directories of the module and shebang scan, default
  `lib scripts`.
- `DEPS`, `DIST`, `VERSION` — the script paths, and the empty version default.

`mk/local.mk` overrides these values, and it appends repo-only targets to the
aggregates. `.toolingrc` stays the identity home of the synced scripts. The two
homes hold different facts: `dist.testdir` names the dist test set, and
`TEST_GLOBS` names the full tier set of `make test`.

### This repository is consumer zero

sync refuses to run inside this repository, so the root holds verbatim copies of
the org files (SYNC-CHECK). This plan extends that rule to the dispatcher and
the fragments:

- The root `Makefile`, `mk/org.mk`, and `mk/perl.mk` equal the canon byte for
  byte.
- `mk/local.mk` points the variables at this tree: the script invocations at
  `org/sync/scripts/` with `--root .`, the source directories at
  `org perl scripts`, and the tiers at `perl/t/*.t`.
- `perl/t/org.t` compares the new root copies.

The variable indirection that consumer zero needs is the same indirection that
every consumer gets.

## Changes

### Change one — the specification

- Add `spec/make.md`, document code `MK`, with five units:
  - MK-VERBS — the vocabulary, the read-only rule, the frozen `deps` names, and
    the `format-md` exclusion.
  - MK-COMPOSE — the aggregation variables, the namespaced sub-targets, the
    include order, and the position of the aggregates.
  - MK-DISPATCH — the org pack owns the root Makefile, the include list is
    fixed, and the dialect lives in the dispatcher alone.
  - MK-SUBSET — the portable fragment subset.
  - MK-LOCAL — the consumer hook `mk/local.mk`: no pack holds it, and it holds
    the build variables and the repo-only targets.
- Add the `MK` row to the document table of `spec/index.md`.
- Add the register rows with state `open`, and a `make.md` row to the code
  roots, in `spec/STATUS.md`.
- Append one rule to the SYNC-IDENTITY unit: build variables live in
  `mk/local.mk`.
- Append one rule to the SYNC-CHECK unit: the root copies of this repository
  extend to the dispatcher and the fragments.
- Add three decisions to `spec/DECISIONS.md`: the ownership with the local hook,
  the vocabulary, and the subset with the GNU dispatcher.

### Change two — the packs, and consumer zero

- Add `org/sync/Makefile` and `org/sync/mk/org.mk`.
- Add `perl/sync/mk/perl.mk`.
- Make `perl/sync/scripts/dist` treat an empty `--version` value as absent.
  Cover the case in `perl/t/dist.t`.
- Replace the root `Makefile` with the canon copy. Add the root `mk/org.mk` and
  `mk/perl.mk` copies, and the local `mk/local.mk`.
- Update the job commands of `.github/workflows/check.yml` to the new verbs.
- Extend `perl/t/org.t` to the new root copies.
- Add `perl/t/make.t`: build a fixture consumer in a temporary directory, sync
  both packs into it, and prove the contract (see the acceptance list).
- Set the five `MK` units to `done` in the register, and delete this plan
  directory.

## Acceptance

- `make check` passes in this repository with the canon Makefile.
- `perl/t/make.t` proves, in the fixture consumer:
  - `make lint`, `make format`, and `make check` run the sub-targets that the
    fragments append.
  - `make format` changes no file, and `make format-fix` writes.
  - `make format-md` exists, and no aggregate contains it.
  - `make deps`, `make deps-test`, and `make deps-develop` resolve.
  - A variable set in `mk/local.mk` overrides a fragment default.
- `perl/t/make.t` also scans the fragments for the constructs that the subset
  bans.
- `perl/t/org.t` proves the root copies equal the canon.
- `make spec-check` and `make ste-lint` pass at each change.

## Out of scope

- The adoption changes of the consumers. Each consumer adopts through its own
  change.
- The BSD dispatcher pair. The portable subset makes it possible later, and a
  later plan can add it.
- A python pack. FuguTTX keeps its uv and ruff targets in its local file until a
  second Python repository exists.
- `install`, `uninstall`, `man`, and the tofu verbs. They stay repo-only
  targets.

## Rejected alternatives

- A consumer-owned root Makefile over synced fragments. Nothing then forces the
  standard target names, and seven `check` wirings drift apart.
- Double-colon rules. One language's lint cannot run alone, and the recipe order
  follows the include order in silence.
- A generated `mk/config.mk` from `.toolingrc`. Generated content breaks the
  verbatim-copy model of D-01, and the check must then regenerate and compare.
- A glob include. The order and the pickup become accidental.
