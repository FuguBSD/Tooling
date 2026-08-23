# 001 — The standard GNUmakefile of the packs

## Status

Proposed. Implements: MK-VERBS, MK-COMPOSE, MK-DISPATCH without MK-DISPATCH-4,
MK-SUBSET, MK-LOCAL, and the rule SYNC-CHECK-4.

The specification is in place: [make.md](../../spec/make.md) states the units.
The register holds one `open` row for each, and decisions D-07, D-08, and D-09
govern them. One implementation change remains, and it can land now. Nothing
waits on another repository.

The BSD dispatcher `Makefile` of MK-DISPATCH-4 waits for a later plan. This plan
prepares for it: every fragment satisfies the portable subset of MK-SUBSET, and
the path `Makefile` stays free. A new dialect then costs one dispatcher file.

Consumer adoption is the work of each consumer, through its own sync change, and
this plan does not describe it. One sequencing fact applies: after the
implementation change, the drift gate of a consumer stays red until its sync
change merges. Adopt the consumers promptly, in any order.

## Purpose

Tooling distributes one standard make interface with standard targets: the
`GNUmakefile` dispatcher and the `mk/` fragments. A language pack composes its
targets into the generic verbs: `make lint`, `make format`, `make check`. Today
every repository hand-writes its root Makefile, and the target names disagree:
`tidy` and `tidy-fix` in the Perl repositories, `fmt` and `fmt-check` elsewhere.
The composition of `check` drifts the same way. A shared dispatcher puts the
target contract under the same drift gate that guards the synced scripts.

## Why Tooling holds this work

The make interface is shared tooling. One canonical copy of every shared tool
lives in this repository (D-01), and a consumer holds a verbatim copy that
`sync --check` verifies. The target names are an interface: the workflows, the
shared actions, and the operators call them in every repository. An interface
that every consumer shares lives in the canon.

## The design

[make.md](../../spec/make.md) states the contract. This section states how the
pieces land.

### Ownership and layout

- `GNUmakefile` — the org pack (MK-DISPATCH-1). The dispatcher: the include
  chain and the generic verbs, and nothing else.
- `mk/org.mk` — the org pack. The `spec-check`, `ste-lint`, `test-prove`,
  `format-md`, and `format-md-fix` targets, and the `CHECK_TARGETS` list of
  MK-COMPOSE-5.
- `mk/perl.mk` — the perl pack. The `lint-perl`, `format-perl`,
  `format-perl-fix`, `dist`, `deps`, `deps-test`, and `deps-develop` targets.
- `mk/local.mk` — the consumer (MK-LOCAL). Build variables and repo-only
  targets. No pack holds the file, and sync never touches it.

No relative path exists in two packs, per SYNC-PACKS-5. The consumer hook
follows the pattern of the synced `CLAUDE.md` (SYNC-IDENTITY-3): a canonical
shell with one local import. The path `Makefile` stays free in every consumer,
per MK-DISPATCH-4, so an adoption change removes the old root `Makefile`.

### The dispatcher

```make
# GNUmakefile: canonical copy, owned by FuguBSD/Tooling.
all: check

-include mk/local.mk
include mk/org.mk
-include mk/perl.mk

check: $(CHECK_TARGETS)
lint: $(LINT_TARGETS)
format: $(FORMAT_TARGETS)
format-fix: $(FORMAT_FIX_TARGETS)
test: $(TEST_TARGETS)
.PHONY: all check lint format format-fix test
```

- `all: check` stands first (MK-DISPATCH-5). The first rule sets the default
  goal in both dialects, so bare `make` runs the commit gate, and no target of
  `mk/local.mk` takes that role. Bare `make` installs nothing: `make deps-test`
  stays an explicit step.
- The include list is fixed (MK-DISPATCH-2). A glob makes the order and the
  pickup accidental.
- `mk/local.mk` loads first, so the consumer sets variables before any fragment
  reads them. A fragment gives its defaults with `?=` (MK-COMPOSE-4).
- The aggregate rules sit at the bottom (MK-COMPOSE-3): make expands a
  prerequisite list at read time.
- `-include` stays silent only on a missing file. A missing fragment of a
  selected pack is drift, and the sync gate reports it.

### Composition

A fragment appends namespaced targets to the aggregation variables of
MK-COMPOSE-1, and it defines those targets. `mk/org.mk` also appends `lint`,
`format`, `test`, `spec-check`, and `ste-lint` to `CHECK_TARGETS`
(MK-COMPOSE-5), so `check` runs every gate:

```make
# mk/perl.mk
LINT_TARGETS += lint-perl
lint-perl:
	...
```

- Every namespaced target stays addressable, for example `make lint-perl`
  (MK-COMPOSE-2). CI keeps its per-tool jobs through the namespaced targets.
- An aggregate is a prerequisite list, so `make -j` runs its targets in
  parallel.

### The vocabulary

A `<verb>` target reads and never writes, and a `<verb>-fix` target writes
(MK-VERBS-1). The verbs are `check`, `lint`, `format`, `format-fix`, and `test`
(MK-VERBS-2). The names `deps`, `deps-test`, and `deps-develop` stay frozen
(MK-VERBS-4): the shared [setup-perl](../../perl/actions/setup-perl/action.yml)
action computes them from its `dependencies` input.

`format-md` and `format-md-fix` run prettier, and they stay out of every
aggregate (MK-VERBS-5). prettier runs through npx, and no deps manifest provides
node. CI runs `make format-md` in its own job, as today. The comment that states
this reason lives in `mk/org.mk`.

The old writer names die with the adoption: `tidy-fix`, `prettier-fix`, and
`fmt`. No alias remains.

### The two dispatchers

The GNU dispatcher `GNUmakefile` ships in this plan, and it matches the dialect
of the current Makefiles. The BSD dispatcher `Makefile` of MK-DISPATCH-4 mirrors
it with the BSD include directives, and a later plan adds it. GNU make prefers a
`GNUmakefile` when both files exist, and BSD make reads `Makefile`, so the pair
serves both dialects side by side. Until the BSD dispatcher lands, an OpenBSD
operator runs `gmake`.

Every fragment satisfies the portable subset of MK-SUBSET from the first change,
so the BSD dispatcher needs no fragment change.

One GNU function falls out of the current Makefiles: the version derivation
through `$(shell git describe ...)`. `scripts/dist` already derives the version
when the flag is absent. The fragment therefore passes `--version '$(VERSION)'`
with an empty default, and `scripts/dist` treats an empty value as absent. CI
keeps `make dist VERSION=1.2.3`, so
[perl-release.yml](../../.github/workflows/perl-release.yml) does not change.

### The variables

[make.md](../../spec/make.md#variables) names the variables. The defaults:

- `SPEC_CHECK`, `STE_LINT` — `scripts/spec-check` and `scripts/ste-lint`.
- `PRETTIER` — `npx prettier@3.9.6`.
- `PROVE`, `TEST_GLOBS` — `prove -l` and `t/ci/*.t`.
- `PERL_SRC_DIRS` — `lib scripts`, the directories of the module and shebang
  scan.
- `DEPS`, `DIST`, `VERSION` — the script paths, and the empty version default.

`mk/local.mk` overrides these values, and it appends repo-only targets to the
aggregates (MK-LOCAL-2).

### This repository is consumer zero

sync refuses to run inside this repository, so the root holds verbatim copies of
shared files (SYNC-CHECK). SYNC-CHECK-4 extends that rule to the dispatcher and
the pack fragments, and this plan implements it:

- The root `GNUmakefile`, `mk/org.mk`, and `mk/perl.mk` equal the canon byte for
  byte, and the root `Makefile` leaves.
- `mk/local.mk` points the variables at this tree: the script invocations at
  `org/sync/scripts/` with `--root .`, the source directories at
  `org perl scripts`, and the tiers at `perl/t/*.t`.
- `perl/t/org.t` compares the new root copies.

The variable indirection that consumer zero needs is the same indirection that
every consumer gets.

## The remaining change

- Add `org/sync/GNUmakefile` and `org/sync/mk/org.mk`.
- Add `perl/sync/mk/perl.mk`.
- Make `perl/sync/scripts/dist` treat an empty `--version` value as absent.
  Cover the case in `perl/t/dist.t`.
- Delete the root `Makefile`. Add the root `GNUmakefile`, the root `mk/org.mk`
  and `mk/perl.mk` copies, and the local `mk/local.mk`.
- Update the job commands of `.github/workflows/check.yml` to the new verbs.
- Update the Layout and Commands sections of the README.
- Extend `perl/t/org.t` to the root `GNUmakefile` and fragment copies.
- Add `perl/t/make.t`: build a fixture consumer in a temporary directory, sync
  both packs into it, and prove the contract (see the acceptance list).
- Set MK-VERBS, MK-COMPOSE, MK-SUBSET, and MK-LOCAL to `done`. Set MK-DISPATCH
  to `partial`, because the BSD dispatcher stays absent. Set SYNC-CHECK to
  `done`. Delete this plan directory.

## Acceptance

- `make check` passes in this repository through the canon `GNUmakefile`.
- `perl/t/make.t` proves, in the fixture consumer:
  - `make lint`, `make format`, and `make test` run the sub-targets that the
    fragments append.
  - `make check` runs `lint`, `format`, `test`, `spec-check`, and `ste-lint`
    (MK-VERBS-3, MK-COMPOSE-5).
  - Bare `make` runs `check` (MK-DISPATCH-5).
  - `make check` and `make format` change no file, and `make format-fix` writes.
  - `make format-md` and `make format-md-fix` exist, and no aggregate contains
    them.
  - `make deps`, `make deps-test`, and `make deps-develop` resolve.
  - A variable set in `mk/local.mk` overrides a fragment default.
  - A repeated sync never delivers and never overwrites `mk/local.mk`
    (MK-LOCAL-1).
  - No pack holds the path `Makefile`.
- `perl/t/make.t` also scans the fragments for the constructs that MK-SUBSET
  bans.
- `perl/t/org.t` proves the root copies equal the canon.
- `make spec-check` and `make ste-lint` pass.

## Out of scope

- The adoption changes of the consumers. Each consumer adopts through its own
  change.
- The BSD dispatcher `Makefile` of MK-DISPATCH-4. A later plan adds it, with no
  fragment change.
- A python pack. FuguTTX keeps its uv and ruff targets in its local file until a
  second Python repository exists.
- `install`, `uninstall`, `man`, and the tofu verbs. They stay repo-only
  targets.

## Rejected alternatives

- The name `Makefile` for the GNU dispatcher. The path then blocks the BSD
  dispatcher, and the later rename touches every consumer. `GNUmakefile` frees
  the path now, and GNU make reads it first.
- A consumer-owned root dispatcher over synced fragments. Nothing then forces
  the standard target names, and seven `check` wirings drift apart.
- Double-colon rules. One language's lint cannot run alone, and the recipe order
  follows the include order in silence.
- A generated `mk/config.mk` from `.toolingrc`. Generated content breaks the
  verbatim-copy model of D-01, and the check must then regenerate and compare.
- A glob include. The order and the pickup become accidental.
