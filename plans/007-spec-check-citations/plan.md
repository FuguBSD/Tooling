# 007 — The plan citation checks of spec-check

A plan can cite one unit under `Implements:` or `Extends:` and under `Defers:`
at the same time. No rule of `spec-check` sees the contradiction. The review
panel found that defect by hand across three rounds of one plan review. The
script also has no specification document: its twelve rules live in its header
comment only. Pull request 26 of this repository names that gap and defers it to
a separate change. This plan adds the contradiction check and the document. The
org pack owns the script, so this repository lands the change first.

## Citations

Implements: none. The design units do not exist yet.

This change adds one document to the specification for `spec-check`. The
document groups the rules of the script header into units. The unit of the plan
rules holds the new check. The change sets each register row in the same change.
This plan names no new rule number, because a number exists only after the rule
lands.

## Decisions

The operator approved these on 2026-09-08. This change must not reverse one
without approval.

| #   | Decision                                                                                                          |
| --- | ----------------------------------------------------------------------------------------------------------------- |
| 1   | A unit must not sit under `Defers:` and under `Implements:` or `Extends:` in one plan.                            |
| 2   | The rules of the script header become units of the specification. The script and the document must agree.         |
| 3   | This plan builds on the `Extends:` change of pull request 26. It repeats none of its work, and it lands after it. |

## Evidence

### The contradiction between the verbs

In one plan review of 2026-08-30, round three reported "`Defers: LIC-LIC`
contradicts step 2 (the licensing table row) and step 10". Round four reported
"the open question states 'LIC-LIC stays open', which contradicts line 8
`Implements: LIC-LIC`". Round five reported "`Implements: LIC-LIC`, but no step
adds a licensing row". Three rounds of three reviewers found a defect that a
one-line check catches in the first.

### Pull request 26 closes the wrapped citation

The branch `feat-extends-citation` makes the citation scan read a paragraph or a
list item as one block, with its wrapped lines joined. It adds the `Extends:`
verb for a `done` unit whose rules change, and rule 12 holds that verb. A
workspace session recorded the wrapped-line gap on 2026-09-05, and the audit of
2026-09-08 found the same gap in a reviewer report. The change on that branch
removes it, so this plan does not.

### The script has no specification unit

The specification documents of this repository cover the sync mechanism, the
make interface, the workflows, and the prose lint. No unit covers `spec-check`.
The script header lists its rules, and the synced `spec/CLAUDE.md` names the
check in one sentence. Pull request 26 recorded the gap as a rejection: "no
specification unit owns spec-check, so the register has no row for rule 12". The
rejection continues: "that holds for rules 1 to 11 too, and a unit for the
script is a separate change."

## Design

### The contradiction check

The check reads each citation of a plan with the block reader of pull
request 26. It collects the unit tokens under `Defers:`, and the unit tokens
under `Implements:` and `Extends:`. A token in both sets is an error that names
the plan and the unit. The check compares unit tokens. A `without` clause names
a rule and leaves the unit token in place. The check runs in every mode, because
it reads the plan text only.

### The document

`spec/spec-check.md` groups the twelve rules of the script header into units.
The document holds the rule text of the script. Where the header text and the
code disagree, the code is the fact, and the document follows the code. The
implementation records each such case in its pull request. The header keeps the
rule numbers and a pointer to the document. The synced `plans/CLAUDE.md` and
`spec/CLAUDE.md` each keep one sentence on the script. That sentence names the
consumer duty and points at the document by its name. For the citation forms,
the document points at the synced `spec/CLAUDE.md` and repeats nothing. The unit
of the plan rules holds rule 10, rule 12, and the contradiction check.
`spec/index.md` gains the row. The register lists every unit as `done`, because
the implementation lands the document and the check together.

### The tests

`perl/t/spec-check.t` gains four fixtures. A plan that cites one unit under
`Implements:` and `Defers:` fails with an error that names the unit. A plan that
cites a `done` unit under `Extends:` and `Defers:` fails the same way. A plan
that cites `Implements: X without X-1` and `Defers: X` fails the same way. A
plan with disjoint sets passes.

## Work

- `org/sync/scripts/spec-check`: the contradiction check, and the header change:
  the rule numbers and a pointer to the document.
- `perl/t/spec-check.t`: the fixtures.
- `spec/spec-check.md` and `spec/index.md`: the new document and its row.
- `org/sync/spec/CLAUDE.md` and `org/sync/plans/CLAUDE.md`: the citation forms
  state that a unit sits under one verb only. Each sentence on the script names
  the consumer duty and points at the document by its name.
- `spec/CLAUDE.md` and `plans/CLAUDE.md`: the root copies of both, by hand.
- `spec/STATUS.md`: the rows, and a Code roots row for `spec-check.md` with
  `org/sync/scripts/spec-check` and `perl/t/spec-check.t`.
- Delete this plan.

## Status

### What lands now

Pull request 26 is merged, and this plan builds on it. Every item of the Work
section lands now. The check reads the citation blocks of that pull request.
Each consumer takes the script through sync afterwards.

### What waits

Nothing waits.
