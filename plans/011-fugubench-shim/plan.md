# 011 — The FuguBench shim replaces the dependency scripts

## Status

Work package 1 can land now. Work package 2 waits on FuguVM. Work package 3
waits on work package 2, and on the rollout of work package 1.

FuguBench D-09 gives this repository the swap. FuguBench v0.1.0 is released, and
it publishes the six assets that FuguBench DIST-ASSETS-1 names. The packed file
runs on core perl v5.34. The install address `https://bench.fugubsd.org/get`
answers with a status of 200.

- Implements: MK-DEPS. The implementation drops the second sentence of
  MK-DEPS-4, retires MK-DEPS-5, and sets the unit to `done`.
- Extends: SYNC-BOOTSTRAP. The implementation adds the shim rules, trims
  SYNC-BOOTSTRAP-1 to the two perl scripts, and retires SYNC-BOOTSTRAP-2.
- Extends: SYNC-MARKER. The implementation adds the shim to the exempt set of
  SYNC-MARKER-4.
- Extends: MK-VERBS. The implementation points the second sentence of MK-VERBS-4
  at the shim.
- Extends: SYNC-KEYS. The implementation keeps SYNC-KEYS-1 and retires each
  other rule of the unit.
- Extends: SYNC-DOWNLOAD. The implementation retires the unit, and work package
  2 retires SYNC-DOWNLOAD-9 before that.
- Extends: SYNC-ALIAS. The implementation retires the unit.
- Extends: SYNC-SUMS. The implementation retires the unit.
- Extends: WFL-CACHE. The implementation changes the file list of WFL-CACHE-1.
- Extends: WFL-SIGN. The implementation points two cross-references of the unit
  at FuguBench.
- Defers: SYNC-PACKS. The org pack gains one file, and no rule of the unit
  changes.
- Defers: SYNC-CHECK. The drift gate of SYNC-CHECK-2 reports the new pack in
  each consumer, and no rule of the unit changes.

## Purpose

The org pack ships `scripts/deps`, a perl installer of about 1900 lines, and
`scripts/ftp`, its downloader. FuguBench now holds that design, and the program
`fugubench` holds the code. FuguBench D-04 puts a wrapper shim in the pack, and
the shim pins one release. This plan swaps the two scripts for that shim.

## Scope

In scope:

- The pack file `org/sync/scripts/fugubench`, and the two files that it
  replaces.
- The `DEPS` value of `mk/org.mk` and of `mk/local.mk`.
- The specification units that describe the installer.
- The setup-perl cache key, and the tests of this repository.

Out of scope:

- The design of the installer. FuguBench D-09 gives it to FuguBench.
- The work of a consumer. Each consumer syncs the pack in a change of its own.
- The move of FuguVM off the `ftp` helper. FuguVM lands that change.
- A cache of the packed file in CI. The shim caches under `HOME`, and a runner
  starts with an empty cache.

## What the tree says

The measurements below come from the checkout, on 2026-09-14.

**FuguVM blocks the deletion of `scripts/ftp`.** `App::FuguVM::Mirror` calls
`Fugu::File->share_path('scripts/ftp')` and runs the helper with `sh`. The key
`dist.share-extra scripts/ftp` of `.toolingrc` ships the file in the
distribution, `mk/local.mk` installs it, and `t/scripts/dist.t` asserts it. An
installed App-FuguVM holds no `fugubench`, so the `fetch` verb cannot serve it.
Fugu LIB-CURL is `done`, and FuguVM uses Fugu already, so FuguVM has a
replacement. That work is a plan of FuguVM.

**The pack file cannot carry the sync marker.** `fugubench shim` prints 59
lines, and FuguBench DIST-SHIM-6 caps the text at 60. The header of the shim
names the pack, but not in the words of SYNC-MARKER-1. `perl/t/marker.t` holds
every pack file to that text. The shim therefore joins the exempt set.

**Twelve repositories hold a `.toolingrc`, and each one holds a `deps`
directory.** This repository is the thirteenth, and `mk/local.mk` points it at
the canon.

**The conformance oracle ends with the swap.** FuguBench
`t/fugubench/deps-conformance.t` reads `scripts/deps` of its own checkout, and
it skips when that file is absent. A sync of work package 3 therefore ends
FuguBench CLI-CONFORMANCE-2.

**Three consumers hold a test that reads the two scripts.** The tests are
`Fugu/t/scripts/conventions.t`, `FuguVM/t/scripts/conventions.t`, and
`FuguWeb/t/scripts/conventions.t`. Each one names a script path, so a sync alone
does not make a consumer green.

## Constraints that shape the design

**No install step precedes `make deps`.** FuguBench D-04 fixes the order. The
shim is POSIX shell, and a fresh clone holds it after a sync. A host needs
`/bin/sh`, one of curl, wget and ftp, one of sha256, shasum and sha256sum, and
perl v5.34. macOS and OpenBSD hold all four in base.

**The shim is the pin.** The text holds the version, the asset URL, and the
sha256 digest. The pack carries no second pin file, and a release of FuguBench
takes one commit here.

**The design lives in FuguBench.** This repository owns the pack, the make
interface, and the sync. It must not repeat a rule of FuguBench DEPS-TIER,
FuguBench DEPS-ALIAS, FuguBench DEPS-SUMS, or FuguBench DEPS-KEYS.

**One fact lives in one place.** SYNC-KEYS-1 says who owns `deps/KEYS.txt`, and
that fact stays here. FuguBench DEPS-KEYS-1 says who reads the file, and that
fact stays there.

**The signify command leaves the install path.** FuguBench DEPS-TIER-8 verifies
a signature in-process. MK-DEPS-4 therefore drops its second sentence, and
MK-DEPS-5 retires.

**A dead file is cheap, and a lost rollback is not.** Work package 1 leaves both
scripts in the pack. A consumer then rolls back with one line, and the FuguBench
oracle still runs.

## The interface contract

The org pack gains `scripts/fugubench`, with mode 755. The file is the output of
`fugubench shim` of the pinned release, byte for byte.

`mk/org.mk` sets `DEPS ?= scripts/fugubench deps`. The three deps targets keep
their names and their order, per MK-VERBS-4 and MK-DEPS-2. `mk/local.mk` of this
repository sets `DEPS = org/sync/scripts/fugubench deps`.

A new release of FuguBench takes two steps here. Run `fugubench shim` of that
release. Write the output to `org/sync/scripts/fugubench`, and commit it. Each
consumer then syncs the pack.

The new rules read as follows. A plan names no rule number, because a number
exists after the rule lands.

- A rule of SYNC-BOOTSTRAP: "The org pack must ship the wrapper shim
  `scripts/fugubench`, with the exec bit. The file must equal the output of
  `fugubench shim` of the pinned release, byte for byte. A new release of
  FuguBench is a new copy of this file."
- A rule of SYNC-BOOTSTRAP: "The shim must need no install step. A fresh clone
  must run `make deps` with `/bin/sh`, a downloader, a digest command, and perl
  v5.34 alone."

## Work packages

### WP1 — The pack ships the shim, and `make deps` calls it

The package can land now. It depends on no other package.

1. Write the output of `fugubench shim` to `org/sync/scripts/fugubench`, with
   mode 755.
2. Set `DEPS ?= scripts/fugubench deps` in `mk/org.mk`, and repair the comment
   above the deps targets.
3. Set `DEPS = org/sync/scripts/fugubench deps` in `mk/local.mk`.
4. Add the shim to the exempt table of `perl/t/marker.t`.
5. Add `perl/t/shim.t`, per the Tests section.
6. Change the deps expectations of `perl/t/make.t` to the new command.
7. Add the shim to `perl/t/sync.t`, beside the two scripts.
8. Add the shim parse to `perl/t/org.t`, beside the parse of `ftp`.
9. Add the two shim rules to SYNC-BOOTSTRAP, and trim SYNC-BOOTSTRAP-1 to
   `sync`, `spec-check`, and `ste-lint`.
10. Retire SYNC-BOOTSTRAP-2, because the shim needs no sibling.
11. Add the shim to SYNC-MARKER-4, and point MK-VERBS-4 and MK-DEPS-1 at the
    shim.
12. Set each touched row of `spec/STATUS.md`, and add each retired ID.

Acceptance:

- `make check` passes.
- `make deps` of this repository installs gitleaks, on a host with no
  `~/.cache/fugubench` directory.
- `perl/t/shim.t` passes, and each new assertion fails against a mutated shim.
- `git grep -n 'scripts/deps' mk org/sync/mk` reports nothing.

### WP2 — `scripts/ftp` leaves the pack

The package waits on FuguVM. FuguVM must first drop the helper, and must ship a
release that holds the replacement.

1. Delete `org/sync/scripts/ftp`.
2. Delete the parse of `ftp` from `perl/t/org.t`, and the two `ftp` assertions
   from `perl/t/sync.t`.
3. Retire SYNC-DOWNLOAD-9, and set the note of the SYNC-DOWNLOAD row.
4. Repair the `dist.share-extra` example of `perl/sync/scripts/dist`, and the
   fixture name of `perl/t/dist.t`.

Acceptance:

- `make check` passes.
- `git grep -n 'scripts/ftp'` reports no file of the pack.
- A sync into a FuguVM checkout leaves `make check` of FuguVM green.

### WP3 — `scripts/deps` leaves the pack

The package waits on work package 2. It also waits on a green work package 1 in
each consumer, and on a recorded pass of FuguBench CLI-CONFORMANCE-2.

1. Delete `org/sync/scripts/deps`, `perl/t/deps.t`, and `perl/t/deps-verify.t`.
2. Delete the compile of `deps` from `perl/t/org.t`.
3. Retire SYNC-ALIAS, SYNC-DOWNLOAD, and SYNC-SUMS, per the retire procedure of
   [spec/CLAUDE.md](../../spec/CLAUDE.md).
4. Keep SYNC-KEYS-1, and retire each other rule of SYNC-KEYS.
5. Drop the second sentence of MK-DEPS-4, retire MK-DEPS-5, and set MK-DEPS to
   `done`.
6. Point the two cross-references of WFL-SIGN-2 and WFL-SIGN-13 at FuguBench,
   and repair the prose above WFL-SIGN-1.
7. Change WFL-CACHE-1 and the action `perl/actions/setup-perl/action.yml` to
   hash `deps/Linux.txt`, `scripts/fugubench`, and `org/sync/scripts/fugubench`.
   Follow with `perl/t/setup-perl.t`.
8. Delete the `signify-openbsd` line of `deps/Linux.txt`, because no test of
   this repository drives the signify tier now.
9. Repair each comment that names a deleted script, in `deps/`, in
   `org/sync/deps/KEYS.txt`, and in the two remaining synced scripts.
10. Set each touched row and each retired ID in `spec/STATUS.md`.

Acceptance:

- `make check` passes.
- `git grep -n 'scripts/deps'` reports no file outside the specification
  history.
- `spec-check` reports a lower unit count, and no unresolved token.
- A sync into each consumer leaves `sync --check` of that consumer green.

## Tests

`perl/t/shim.t` is the new gate of this repository. It reads the pack file, and
it asks no network. It must assert:

- `sh -n` parses the file, and the file holds fewer than 61 lines.
- The file starts with `#!/bin/sh`, and the exec bit is set.
- The `version` value is a dotted-decimal number.
- The `url` value holds that version, and it ends in `/fugubench`.
- The `want` value is 64 hexadecimal characters.
- With `FUGUBENCH` set to a stub script, the shim runs that stub, passes each
  argument through, and returns the exit code of the stub.
- With `FUGUBENCH` set to a path that names no executable, the shim reports the
  value and exits non-zero.
- With `FUGUBENCH` set to an empty value, the shim downloads nothing.

The last three assertions cover FuguBench DIST-SHIM-2 and FuguBench DIST-SHIM-5
from the side of the consumer. The stub makes each one run with no network.

## What this repository cannot prove

The trace of `fugubench deps` equals the trace of `scripts/deps` over the
manifests of every consumer. FuguBench CLI-CONFORMANCE-2 owns that oracle, and
630 assertions hold it. This repository holds no copy, and it must not add one.
Work package 3 therefore needs a recorded pass of that test first.

The digest of the shim binds the bytes of the release. A check of that digest
needs the network, and no test here downloads. FuguBench DIST-SHIM-1 computes
the value, and FuguBench holds it.

## Rollback

A consumer that finds the shim wrong sets `DEPS = scripts/deps` in
`mk/local.mk`, per MK-LOCAL-2. That is one line, and it needs no sync. The
rollback works until work package 3 lands.

The whole organization rolls back with one revert of the `mk/org.mk` line here,
and one sync in each consumer.

One host takes a known good program with `FUGUBENCH` in the environment. That
covers a bad release on one machine.

A bad pin takes one commit here. Write the shim of the earlier release to
`org/sync/scripts/fugubench`, and each consumer syncs.

After work package 3 the two scripts live in the history alone. A rollback then
restores them from a tag. Work package 3 waits on a green rollout for that
reason.

## Open questions

1. The citation vocabulary holds no verb for a retirement. This plan cites each
   retired unit under `Extends:`, which `spec/CLAUDE.md` defines as a change of
   a rule. A reviewer must accept that reading, or must name a better one.
2. FuguBench can keep its oracle after work package 3, with a frozen copy of
   `scripts/deps` under `t/`. That decision belongs to FuguBench.
3. Each CI job downloads 393014 bytes on a cold cache. A cache of
   `~/.cache/fugubench` can remove it, and no measurement says that the cost
   matters yet.
