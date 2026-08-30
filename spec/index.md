# Tooling specification

The Tooling repository holds the shared build, dist and release tooling of the
FuguBSD repositories. One canonical copy of every shared tool lives here. A
consumer references the actions and the reusable workflows at `@main`, and holds
verbatim copies of the synced files.

This document is the entry point of the specification. It holds the plan
contract, the ID conventions, and the document tables.

## Plan contract

- Read [DECISIONS.md](DECISIONS.md) before you make a plan.
- A plan must not go against a decision. To go against a decision, propose a
  change to [DECISIONS.md](DECISIONS.md) and get human approval first.
- A plan must cite each unit that it implements, for example
  `Implements: SYNC-PACKS`.
- A plan can exclude a rule from a cited unit with `without`, for example
  `Implements: SYNC-PACKS without SYNC-PACKS-2`.
- A plan must cite each unit that it touches but defers, for example
  `Defers: WFL-CACHE`.
- The change that implements a unit, or a part of a unit, must set the state of
  the unit in [STATUS.md](STATUS.md) in the same change.

<a id="conventions"></a>

## Conventions

The ID overlay lives in [spec/CLAUDE.md](CLAUDE.md): the unit anchors, the rule
shape, the append-only numbers, the retire procedure, and the citation forms.

## Specification documents

Each document specifies one area of work. The code of a document prefixes the
IDs of its units.

| Code | Document                     | Area                               |
| ---- | ---------------------------- | ---------------------------------- |
| SYNC | [sync.md](sync.md)           | The sync mechanism and the packs   |
| MK   | [make.md](make.md)           | The make interface and dispatchers |
| WFL  | [workflows.md](workflows.md) | Actions and reusable workflows     |
| STE  | [ste-lint.md](ste-lint.md)   | The prose lint                     |

## Governance documents

These documents carry no units.

| Document                     | Role                                                  |
| ---------------------------- | ----------------------------------------------------- |
| [DECISIONS.md](DECISIONS.md) | The decisions. A plan must not go against a decision. |
| [ROADMAP.md](ROADMAP.md)     | The schedule of the work.                             |
| [STATUS.md](STATUS.md)       | The implementation register.                          |
