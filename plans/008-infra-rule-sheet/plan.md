# 008 — The infra rule sheet

`infra/CLAUDE.md` of the infra pack holds 2,331 words. It enters the context of
a session on the first touch of a file under `infra/`, at about 3,800 tokens,
and it mixes the rules that an agent needs at edit time with design narrative,
reference tables, and procedures. This plan cuts the file to a rule sheet under
500 words. The shared design moves to a specification document of this
repository, and the pack file points at it. A project fact stays in the consumer
specification and the consumer runbook, as today.

## Citations

Implements: none. The design units do not exist yet.

This change adds one document to the specification for the shared infrastructure
design: the state, the credentials, the spend guardrails, the task runner, and
the CI shape. Consumer code implements each unit, so each register row is `n-a`.
SYNC-PACKS-6 stays as it is: the infra pack still holds the shared instructions
at `infra/CLAUDE.md` of the consumer. This plan names no new rule number,
because a number exists only after the rule lands.

## Decisions

The operator approved these on 2026-09-08. This change must not reverse one
without approval.

| #   | Decision                                                                                                                                                                                      |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | A synced `CLAUDE.md` is a rule sheet: one rule for each bullet, no table above five rows, and no procedure.                                                                                   |
| 2   | The shared infrastructure design lives in a specification document of this repository. The pack file points at it with a URL, because a synced file cannot hold a relative link into Tooling. |
| 3   | A project fact lives in the consumer specification or the consumer runbook, and never in the pack.                                                                                            |

## Evidence

### The file is the largest instruction load

The audit of 2026-09-08 measured each nested rule file that entered a session
context. `infra/CLAUDE.md` entered at 14,868 to 15,147 characters, the largest
single injection. The other rule files enter at 1,200 to 3,000 characters. The
audit of the panel reviewers counted 58 reads of the file.

### The file holds three kinds of text

A count of the sections gives about 450 words of credential design and
procedure, 330 words of spend guardrails, 250 words of state design, 200 words
of CI table and rules, 200 words of task runner list, and 180 words of teardown
narrative. The rules that an agent applies at edit time make up about a third of
the file.

### The consumer documents hold the project facts

The workspace README names `Projects/FuguTTX/spec/infrastructure.md` as the
canonical infrastructure document. It holds sections on the stacks, the spend
guardrails, the task runner, and the resources outside OpenTofu. The consumer
runbook `infra/persistent/RUNBOOK.md` holds the credentials, the change
procedure, and the recovery. The pack file repeats a part of each.

## Design

### What stays in the pack file

Each rule that an agent applies when it edits a stack:

- The ground rules: OpenTofu declares each resource, the ISC license, the live
  price before a create, the 60-minute billing minimum.
- The naming rules, with the pointer to the Repositories specification.
- The region, the zone, and the endpoint, in one table of three rows.
- The version pins, in one table of two rows, and the two rules on `versions.tf`
  and the lock file.
- The four stack names, and the three layout rules: no remote state read, no
  hardcoded UUID, a module at three callers.
- The tag table of five rows, and the rule on an ad-hoc resource.
- The four bucket rules.
- The backend rules: the lock file, no `-lock=false` on an apply, the
  `endpoints` form, no key in the backend block, the encryption of state and
  plan, and no key creation by OpenTofu.
- The credential rules: the persistent stack declares each application and no
  key, every local command names its profile, CI exports one credential set, the
  provider block holds no key, and a rotation is a create and a delete.
- The guardrail rules: a quota of one for each compute offer, one monthly budget
  that only a human raises, the forecast check before each apply, and the
  watchdog scope.
- The five verification rules.
- The teardown rules: the destroy order, the IPv4 address, and the reconcile
  before a teardown ends.
- The task runner rules: `make check` calls `make infra-check`, and no hardcoded
  price.
- The CI rules: no `pull_request_target`, no plan on a fork, `infra-apply` on
  `main` only, and one concurrency group for each stack with `queue: max`.

One sentence at the top points at the design document by URL.

### What moves to the design document

`spec/infra.md` of this repository takes the narrative and the reference
material: the layout tree, the three controls on the state and the bucket policy
caution, the four IAM applications with their scopes, the rotation procedure,
the train credential procedure, the SSH key note, the guardrail table, the
forecast check and the idle definition, the teardown narrative, the task runner
list, and the CI table. Each part becomes a unit, and the register marks each
unit `n-a`, because consumer code implements it.

### What the consumers do afterwards

A consumer specification that repeats a part of the design document can point at
it instead. That work belongs to each consumer, and this plan does not describe
it.

## Work

- `infra/sync/infra/CLAUDE.md`: the rule sheet, under 500 words.
- `spec/infra.md` and `spec/index.md`: the design document and its row.
- `spec/STATUS.md`: the rows, each `n-a`.
- Delete this plan.

## Status

### What lands now

Every item of the Work section lands now. Each infra consumer takes the rule
sheet through sync afterwards.

### What waits

The consumer pointers wait for each consumer.

### Open questions

1. The design document holds units that no Tooling code implements. The register
   state `n-a` exists for that case. The operator confirms the state before the
   document lands.
