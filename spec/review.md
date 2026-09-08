# The review procedure

A minor-level or major-level change merges through a pull request and a review
panel (D-10). This document specifies the bounded panel loop, the agent
definitions, and the merge skills. The org pack of
[the sync mechanism](sync.md#sync-packs) owns each file, so every consumer runs
one procedure.

<a id="rev-loop"></a>

## The bounded loop

A round reviews one committed diff with three independent reviewers. The ledger
`explore/review/ledger.md` records each finding, and `explore/` is gitignored in
every consumer.

- **REV-LOOP-1** — The main session must run `make check </dev/null` and must
  commit every change before a round. Before round one it must write
  `git diff <base>...HEAD` to `explore/review/base.diff`.
- **REV-LOOP-2** — A round must launch three `reviewer` agents with one fixed
  prompt of the skill. The prompt must hold the repository path, the diff path,
  the ledger path, and the round number.
- **REV-LOOP-3** — Two reports match when they name the same file and the same
  defect. A blocker that two members report is a quorum finding, and it takes
  the disposition `accepted`.
- **REV-LOOP-4** — A blocker of one member must take the disposition `open`. The
  next round must confirm it or drop it. A second member makes it `accepted`.
- **REV-LOOP-5** — Round one and round two must launch one `fixer` agent when
  the round holds an accepted finding. The fixer must get the repository path,
  the diff path, and the ledger path.
- **REV-LOOP-6** — Round two and round three must review the fix diff of the
  last round, and each file that the fixer report cites. A reviewer must confirm
  every `fixed` entry, and must report a new defect inside that scope only.
- **REV-LOOP-7** — The loop must stop after a round with no quorum finding, or
  after round three. A fixer that commits nothing also stops the loop, and the
  main session must write no fix diff. Round three must run no fixer.
- **REV-LOOP-8** — The main session must dispatch. After the first launch of a
  round it must edit no repository file. A file under `explore/` is scratch
  space, and not a repository file.
- **REV-LOOP-9** — Each ledger line must hold the finding number, the round, the
  file and the line, the severity, each member that reported it, and the
  disposition. A severity is `blocker` or `minor`. A disposition is `open`,
  `accepted`, `fixed`, `rejected: <reason>`, `dropped`, or `recorded`.
- **REV-LOOP-10** — A minor finding must take the disposition `recorded`, and no
  round must fix it. A rejection must cite the code, the specification, or a
  decision.
- **REV-LOOP-11** — The residue is each quorum finding of round three, each
  `open` entry, and each accepted finding of a round with no fix commit. The
  pull request body must hold the residue, and the operator must decide it.
- **REV-LOOP-12** — After the fixer of round `<N>` commits, the main session
  must write `git diff <round commit>...HEAD` to `explore/review/fix-<N>.diff`.
  Round `<N+1>` must read that file as its diff path.

<a id="rev-agents"></a>

## The agent definitions

The org pack holds three agent files under `.claude/agents/`. Every consumer
receives them, so no session writes its own wrapper.

- **REV-AGENTS-1** — The pack must hold `reviewer.md`, `fixer.md`, and
  `implementer.md`. The marker of each file must come after its front matter,
  per [the marker](sync.md#sync-marker).
- **REV-AGENTS-2** — `reviewer.md` must name `Edit`, `Write`, and `NotebookEdit`
  in `disallowedTools`, and must set `effort` to `high`. Its prompt must forbid
  a write.
- **REV-AGENTS-3** — The reviewer must read the diff file, each file that the
  diff names, and the rule file of each changed directory. It must not derive
  the diff, and it must not run a gate.
- **REV-AGENTS-4** — The reviewer must report at most ten findings, or the words
  "no findings". The line form is `FILE:LINE — DEFECT [blocker|minor]`. It must
  not report a defect that `make check` catches, and it must not report a style
  preference.
- **REV-AGENTS-5** — `fixer.md` must take the full tool set, the `effort` value
  `xhigh`, and the `permissionMode` value `acceptEdits`. It must make the
  smallest change for each finding, name the directory in every command, run
  `make check </dev/null`, and commit with the round number.
- **REV-AGENTS-6** — The fixer must report one disposition for each finding, and
  each file that it touched.
- **REV-AGENTS-7** — `implementer.md` must take the shape of the fixer. It must
  receive one plan section and its acceptance test. It must commit, and it must
  report each file that it touched and the test result.
- **REV-AGENTS-8** — The test `perl/t/agents.t` must hold each agent file to its
  front matter. The `name` value must equal the file stem, a `description` value
  must exist, and the reviewer must deny the edit tools.

<a id="rev-merge"></a>

## The merge skills

The org pack holds `merge-it`, `pull-it`, and `review-panel` under
`.claude/skills/`. D-10 needs the panel in every repository, and a standalone
project session needs the merge procedure.

- **REV-MERGE-1** — `pull-it` must hold a size gate before the panel: one plan
  or one feature for each change set.
- **REV-MERGE-2** — `pull-it` must dispatch a `fixer` agent for a failed check
  of the pull request.
- **REV-MERGE-3** — `pull-it` must end with a stop line: the next change starts
  in a new session.
- **REV-MERGE-4** — The pull request body must hold the round table. The table
  holds the round, the finding count, the quorum count, and the residue.
  `.github/pull_request_template.md` must carry the table, in place of a review
  checklist line.
- **REV-MERGE-5** — `pull-it` must run the panel one time for each change set.
  It must push each fix commit of the panel, and must watch the checks once more
  before the merge.
