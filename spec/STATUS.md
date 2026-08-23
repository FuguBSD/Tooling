# Implementation register

This register is the one record of implementation state. One row exists for each
unit of the specification. A unit is one design element of one specification
document. The [conventions](index.md#conventions) define the unit IDs. Each row
describes the current state only. A row must not carry a plan name or a
reference to an earlier state. A note can carry the date of a recorded fact.

## States

| State   | Meaning                                                              |
| ------- | -------------------------------------------------------------------- |
| open    | No code implements the unit.                                         |
| partial | Code implements a part of the unit. The note names each absent part. |
| done    | Code implements the full unit. The note links the code or the tests. |
| n-a     | No code can implement the unit. It exists for citation only.         |

The "Done by" column names a phase of the [roadmap](ROADMAP.md), or "—" when no
phase applies.

## Units

| Unit                                     | State   | Done by | Note                                                                                                                     |
| ---------------------------------------- | ------- | ------- | ------------------------------------------------------------------------------------------------------------------------ |
| [SYNC-PACKS](sync.md#sync-packs)         | done    | —       | [sync](../scripts/sync), [sync.t](../perl/t/sync.t)                                                                      |
| [SYNC-IDENTITY](sync.md#sync-identity)   | done    | —       | [org/sync](../org/sync), [sync.t](../perl/t/sync.t)                                                                      |
| [SYNC-CHECK](sync.md#sync-check)         | partial | —       | The root dispatcher and fragment copies of SYNC-CHECK-4 are absent. [sync.t](../perl/t/sync.t), [org.t](../perl/t/org.t) |
| [SYNC-BOOTSTRAP](sync.md#sync-bootstrap) | done    | —       | [deps](../org/sync/scripts/deps), [deps.t](../perl/t/deps.t)                                                             |
| [MK-VERBS](make.md#mk-verbs)             | open    | —       | —                                                                                                                        |
| [MK-COMPOSE](make.md#mk-compose)         | open    | —       | —                                                                                                                        |
| [MK-DISPATCH](make.md#mk-dispatch)       | open    | —       | —                                                                                                                        |
| [MK-SUBSET](make.md#mk-subset)           | open    | —       | —                                                                                                                        |
| [MK-LOCAL](make.md#mk-local)             | open    | —       | —                                                                                                                        |
| [WFL-ACTIONS](workflows.md#wfl-actions)  | done    | —       | [workflows.t](../org/sync/t/ci/workflows.t)                                                                              |
| [WFL-REUSE](workflows.md#wfl-reuse)      | done    | —       | [perl-build.yml](../.github/workflows/perl-build.yml), [perl-release.yml](../.github/workflows/perl-release.yml)         |
| [WFL-WEB](workflows.md#wfl-web)          | done    | —       | [web-publish.yml](../.github/workflows/web-publish.yml)                                                                  |
| [WFL-CACHE](workflows.md#wfl-cache)      | done    | —       | [setup-perl](../perl/actions/setup-perl/action.yml), [setup-perl.t](../perl/t/setup-perl.t)                              |

## Update protocol

1. The change that implements a unit, or a part of a unit, sets the state of the
   unit in this register, in the same change.
2. A `partial` note names each absent rule or part.
3. A `done` note holds at least one relative link to code or to tests.

## Code roots

The drift gate maps each document to the code that implements it.

| Document     | Roots                                                                  |
| ------------ | ---------------------------------------------------------------------- |
| sync.md      | `scripts/sync`, `org/sync`, `perl/sync`, `perl/t`                      |
| make.md      | `org/sync`, `perl/sync`, `perl/t`                                      |
| workflows.md | `.github/workflows`, `actions`, `perl/actions`, `org/sync/t`, `perl/t` |

## Retired IDs

| ID  |
| --- |
