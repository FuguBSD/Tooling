# 008 — The infra rule sheet

`infra/CLAUDE.md` of the infra pack holds 2,331 words. It enters the context of
a session on the first touch of a file under `infra/`, at about 3,800 tokens. It
mixes the rules that an agent needs at edit time with design narrative,
reference tables, and procedures. This plan cuts the file to a rule sheet under
1,100 words. The shared design moves to a specification document of this
repository, and the pack file points at it. A project fact stays in the consumer
specification and the consumer runbook, as today.

## Citations

Implements: none. The design units do not exist yet.

This change adds one document to the specification for the shared infrastructure
design. The document covers the state, the credentials, the spend guardrails,
the task runner, and the CI shape. Consumer code implements each unit, and no
code of this repository can. Each register row is `n-a`, per decision 4.
SYNC-PACKS-6 stays as it is: the infra pack still holds the shared instructions
at `infra/CLAUDE.md` of the consumer. This plan adds no rule to SYNC-PACKS: the
rule-sheet shape is decision 1, and it lands in `spec/DECISIONS.md`.

## Decisions

The operator approved these on 2026-09-08. This change must not reverse one
without approval.

| #   | Decision                                                                                                                                                                                      |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | A synced `CLAUDE.md` is a rule sheet: one rule for each bullet, no table above five rows, and no procedure.                                                                                   |
| 2   | The shared infrastructure design lives in a specification document of this repository. The pack file points at it with a URL, because a synced file cannot hold a relative link into Tooling. |
| 3   | A project fact lives in the consumer specification or the consumer runbook, and never in the pack.                                                                                            |
| 4   | The states table of `spec/STATUS.md` changes: `n-a` covers a unit that no code of this repository can implement.                                                                              |

## Evidence

### The file is the largest instruction load

The audit of 2026-09-08 measured each nested rule file that entered a session
context. `infra/CLAUDE.md` entered at 14,868 to 15,147 characters, the largest
single injection. The other rule files enter at 1,200 to 3,000 characters. The
audit of the panel reviewers counted 58 reads of the file.

### The file holds three kinds of text

A count of the sections gives about 450 words of credential design and
procedure, and 330 words of spend guardrails. The state design takes 250 words,
and the CI table and rules take 200 words. The task runner list takes 200 words,
and the teardown narrative takes 180 words. The rules that an agent applies at
edit time make up about a third of the file.

### The consumer documents hold the project facts

The workspace README names `Projects/FuguTTX/spec/infrastructure.md` as the
canonical infrastructure document. It holds sections on the stacks, the spend
guardrails, the task runner, and the resources outside OpenTofu. The FuguSTX
runbook `infra/persistent/RUNBOOK.md` holds the credentials, the change
procedure, and the recovery. The pack file repeats a part of each.

## Design

### What stays in the pack file

Each rule that an agent applies when it edits a stack:

- The ground rules: OpenTofu declares each resource, the ISC license, the
  Scaleway platform, the live price before a create, and the 60-minute billing
  minimum.
- The naming rules, with the pointer to the Repositories specification.
- The region, the zone, and the endpoint, in one table of three rows.
- The version pins, in one table of two rows, and the two rules on `versions.tf`
  and the lock file. The ban on `action` resources and list resources.
- The four stack names, and the stack file set. The three layout rules: no
  remote state read, no hardcoded UUID, a module at three callers.
- The tag rule with its one-map build, the tag table of five rows, and the rule
  on an ad-hoc resource.
- The four bucket rules.
- The backend rules: the lock file, no `-lock=false` on an apply, the
  `endpoints` form, and no key in the backend block.
- The three state controls: the encryption of state and plan, the bucket policy
  that names each principal, and no key creation by OpenTofu.
- The credential rules: the persistent stack declares each application and no
  key, and every local command names its profile. CI exports one credential set,
  the provider block holds no key, and a rotation is a create and a delete.
- The guardrail rules: a quota of one for each compute offer, and one monthly
  budget that only a human raises. The forecast check before each apply and the
  watchdog scope also stay.
- The five verification rules.
- The teardown rules: the destroy order, the IPv4 address, and the reconcile
  before a teardown ends.
- The task runner rules: `make check` calls `make infra-check`, and no hardcoded
  price.
- The CI rules: no `pull_request_target`, no plan on a fork, `infra-apply` on
  `main` only, and one concurrency group for each stack with `queue: max`.

These parts hold 1,092 words in the file today, by `wc -w`. The target is 1,100
words, the count rounded up to the next hundred.

One sentence at the top points at the design document by URL.

### What moves to the design document

`spec/infra.md` of this repository takes the narrative and the reference
material. It takes the layout tree, the state bucket versioning and its
lifecycle, the rationale of the state controls, and the bucket-policy caution.
It takes the four IAM applications with their scopes, the policy retry, the
rotation procedure, the train credential procedure, and the SSH key note. It
takes the guardrail table, the alert thresholds, the forecast formula, the idle
definition, and the watchdog cadence. It takes the teardown narrative, the task
runner list, the CI table, and the Audit Trail export. Each part becomes a unit,
and the register marks each unit `n-a`, because consumer code implements it. The
design document repeats no rule of the pack file.

### What the consumers do afterwards

A consumer specification that repeats a part of the design document can point at
it instead. That work belongs to each consumer, and this plan does not describe
it.

## Work

- `infra/sync/infra/CLAUDE.md`: the rule sheet, under 1,100 words.
- `spec/infra.md` and `spec/index.md`: the design document and its row.
- `spec/DECISIONS.md`: decision 1, the rule-sheet shape, with the word limit of
  the infra rule sheet.
- `spec/STATUS.md`: the states table, per decision 4, and the rows, each `n-a`.
- Delete this plan.

## Status

### What lands now

Every item of the Work section lands now. Each infra consumer takes the rule
sheet through sync afterwards.

### What waits

The consumer pointers wait for each consumer.
