# 005 — The review panel, version 2

The `review-panel` skill repeats until no quorum finding remains, and it names
no one to make the fix. In practice the main session of a merge applies every
fix itself, at a context of 300k to 700k tokens. Each fix gives the next round
new text to review. One change set ran seven rounds. This plan bounds the loop
at three rounds, moves each fix to a cold agent, and gives the panel fixed agent
definitions. The org pack owns the skills, so this repository lands the change
first. Each consumer then takes the synced files.

## Citations

Implements: none. The design units do not exist yet.

This change adds one document to the specification for the review procedure. Its
units cover the bounded loop, the agent definitions, and the merge skills. It
adds one decision. It sets each register row in the same change. This plan names
no new rule number, because a number exists only after the rule lands.

## Decisions

The operator approved these on 2026-09-08, after an audit of the session traces
and three independent replications of it. This change must not reverse one
without approval.

| #   | Decision                                                                                                                                                                                                           |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | The main session of a merge dispatches. After the first panel launch it edits no repository file. The review scratch files under `explore/` are not repository files. A fixer agent applies each accepted finding. |
| 2   | Three rounds are the cap. A residue goes to the pull request body, and the operator decides.                                                                                                                       |
| 3   | A round reviews a committed diff. Round two and round three review the fix diff and the files that the fix cites.                                                                                                  |
| 4   | "No findings" is a normal result. Each finding carries a severity, blocker or minor. The quorum rule applies to a blocker. A minor finding is recorded, not fixed in the round.                                    |
| 5   | The reviewer, the fixer and the implementer are agent definitions in the org pack. Every consumer receives them.                                                                                                   |
| 6   | The three merge skills stay in the org pack. D-10 needs the panel in every repository, and a standalone project session needs the merge procedure.                                                                 |

Decision 5 does not touch the workspace decision on the observer set. That set
operates three projects from outside them, so it lives in the workspace only.
The review agents operate the repository that holds them, so a pack copy has a
target in every consumer.

Decision 6 departs from the first request of the operator, which asked to remove
the skills from the projects. The revised proposal kept them, and the operator
approved the revised proposal.

## Evidence

An audit of 72 sessions from 2026-08-18 to 2026-09-07 measured each claim below
on 2026-09-08. Three independent sub-agents repeated the audit and confirmed the
figures.

### The loop has no exit

Eighteen sessions ran a panel, 79 rounds in all. One change set of five plans
ran seven rounds. Its rounds returned 30, 27, 29, 29, 21, 21 and 25 findings,
and the quorum count never reached zero. The traces hold 248 reviewer
transcripts. The count exceeds 79 rounds of three because some transcripts
belong to sessions whose main file is absent. Of the 248, 26 said "no findings".
The operator stopped one loop by hand: "Let's round 3 be the last round".

### The main session makes every fix

No window between two panel rounds held a fix sub-agent. The main session made
about 950 `Edit` and `Write` calls and about 300 Bash writes inside review
loops. In the panel sessions, 81 percent of the main-session input tokens came
after the first panel launch. The main session also fixed single-member
findings, against the quorum rule of the skill: "I'll fix those plus the valid
singles".

### The fixes make the next findings

From round two on, 30 to 90 percent of the files that a round named were fresh
edits. The main session had edited them since the previous round. In one session
round six named eleven files, and ten of them were fresh edits. The main session
admitted the effect: "A few of the round-four rewrites reintroduced sentences
over the limit." A round also reviewed a stale diff. One report said: "Three
round-2 defect repairs sit uncommitted in the working tree, so the review diff
and the PR are stale."

### Each reviewer re-derives the change

The skill says "plus the diff", and the sessions passed a path or a description
instead. Two sessions of eighteen embedded the diff. The reviewers ran
`git diff` or `git show` 393 times and a `make check` target 255 times. A
reviewer cost 60k to 215k tokens and wrote a median 18k output tokens. A
reviewer ran a median 16 requests, a 90th percentile of 28, and a maximum of 41.

### The wrapper varied

Sixteen sessions loaded the skill text. Each one then wrote its own wrapper
around the review prompt, 963 to 7,118 characters, in the background or in the
foreground. No dispatch set a model or an effort.

### The dispatch pattern works

One session dispatched two implementer agents, with 115 and 123 edits, for two
plans. The campaign session that ran the observer set dispatched 32 agents and
kept its main context at 255k over six hours.

## Design

### The ledger

`explore/review/ledger.md` holds one line for each finding. Each line holds the
finding number, the round, the file and line, the severity, the members that
reported it, and the disposition. A disposition is `open`, `accepted`,
`fixed <hash>`, `rejected: <reason>`, `dropped`, or `recorded`. A rejection
cites the code, the specification, or a decision. An `accepted` entry is a
quorum finding that waits for the fixer. An `open` entry is a blocker that one
member reported. The next round confirms it or drops it. A confirmed entry
becomes `accepted` when two members confirm it. A dropped entry gets the
disposition `dropped`. An `open` entry after the last round joins the residue.
The `explore/` directory is gitignored in every consumer.

### The round

1. The main session runs `make check </dev/null`. It commits every change. It
   writes `git diff <base>...HEAD` to `explore/review/round-<N>.diff`, and the
   changed-file list beside it.
2. It launches three `reviewer` agents in the foreground, with one fixed prompt
   from the skill. The prompt holds the repository path, the diff path, the
   ledger path, and the round number. It writes no other prompt text.
3. It merges the reports into the ledger. A blocker that two members report is a
   quorum finding with the disposition `accepted`. A blocker that one member
   reports stays `open`. A minor finding gets the disposition `recorded`.
4. In rounds one and two, it launches one `fixer` agent when the round has a
   quorum finding. Without one, the skill stops per step 6. The fixer gets the
   repository path, the diff path, and the ledger path. The main session edits
   no repository file itself.
5. Round two and round three review the fix diff,
   `git diff <round commit>...HEAD`. They also review the files that the fixer
   report cites. A reviewer confirms each `fixed` entry by its hash, and reports
   a new defect in that scope only. The reviewers also get each `open` entry. A
   reviewer confirms it or drops it.
6. The skill stops after a round with no quorum finding, or after round three.
   Round three has no fixer. The residue is the quorum findings of round three
   plus each `open` entry. The pull request body gets the round table. The table
   holds the round, the finding count, the quorum count, the fixer commit, and
   the residue.

### The reviewer

The agent file `reviewer.md` has no edit tool: `disallowedTools` names `Edit`,
`Write` and `NotebookEdit`. It keeps Bash for `git show`, `git diff` and `grep`,
and the prompt forbids a write. It sets effort `high` and `maxTurns` at 40. The
turn cap comes from the measured distribution, and it can fall after the
diff-bound prompt proves shorter. The prompt tells the reviewer to read the diff
file and the files it names, and the rule files of the changed paths. It does
not run the gates and it does not derive the diff. It reports each defect as
`FILE:LINE — DEFECT [blocker|minor]`, at most ten, or "no findings".

### The fixer

The agent file `fixer.md` sets the full tool set, effort `xhigh`, and
`permissionMode: acceptEdits`. With that mode, the Bash steer of auto mode does
not apply to it. Its rules are:

- Change the line that the finding names.
- Do not rewrite the file.
- Name the directory in every command.
- Run `make check </dev/null` before the report.
- Commit with the round number.

It returns one disposition per finding, and the list of files that the fix
touched.

### The implementer

The agent file `implementer.md` has the shape of the fixer. It receives a plan
section, a file list, and the acceptance test. It commits, and it reports the
files it touched and the test result. The main session holds the plan and
dispatches one implementer for each work package.

### The merge skills

`pull-it` gains a size gate before the panel: one plan or one feature for each
change set. A diff above about 600 lines splits first. It dispatches a `fixer`
for a CI failure. It ends with a stop line after the merge: start a new session
for the next change. `merge-it` does not change.

### The pull request template

The checklist line on the review panel becomes the round table. The template
carries no marker, so the change touches no test.

### Tests

`perl/t/marker.t` covers each new pack file with no change. A new test
`perl/t/agents.t` holds each agent file to its front matter. The `name` equals
the file stem, a `description` exists, and the reviewer disallows the edit
tools. `perl/t/org.t` requires a root copy of each org file, so the root
`.claude/agents/` copies land in the same change.

## Work

- `org/sync/.claude/skills/review-panel/SKILL.md`: the bounded loop, the ledger,
  the fixed prompt, and the round table.
- `org/sync/.claude/skills/pull-it/SKILL.md`: the size gate, the fixer for a CI
  failure, and the stop line.
- `org/sync/.claude/agents/reviewer.md`, `fixer.md`, `implementer.md`: the three
  agent files, each with the marker after its front matter.
- `org/sync/.github/pull_request_template.md`: the round table.
- `spec/review.md` and `spec/index.md`: the new document and its row.
- `spec/DECISIONS.md`: the decision. The main session dispatches and edits no
  repository file during a panel, and the review agents live in the org pack.
- `spec/STATUS.md`: the rows of the new units.
- `perl/t/agents.t`: the front matter test.
- The root copies under `.claude/` and `.github/`, by hand. `perl/t/org.t` holds
  each root copy to the canon.
- Delete this plan.

## Status

### What lands now

Every item of the Work section lands now. The change stays inside this
repository, and each consumer takes it through sync afterwards.

### What waits

The two hooks wait for a measured pilot. One is a lint hook on each edit of a
Markdown file, scoped to the fixer. The other is a gate hook at the stop of the
fixer. The lint hook needs a single-file mode of `ste-lint`, which plan 006
adds. The lint hook must match the Bash tool as well as `Edit` and `Write`.

The workspace session rules wait for the workspace plan. A synced file cannot
hold a workspace-only rule.

### Open questions

1. The fixer sets `permissionMode: acceptEdits`. A probe must confirm that the
   setting removes the Bash steer of auto mode for that agent. It must also
   confirm that the edits still run without a prompt.
2. `maxTurns` counts agentic turns. The value 40 assumes that unit. A probe
   confirms it before the reviewer file lands.
3. A probe must confirm that the `effort` field of an agent file overrides the
   session effort. The probe runs in the current Claude Code version.
