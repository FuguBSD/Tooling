# 006 — Sentence rules and a single-file mode for ste-lint

The writing standard sets a 20-word limit for an instruction sentence and a
25-word limit for a descriptive sentence. No tool checks either limit. The
review panel reports them in every round, and the main session of one merge
wrote a scan script for the same job. This plan adds the two sentence rules to
`ste-lint`, and a `--file` mode that a hook or an agent can call on one file.
The org pack owns the script, so this repository lands the change first. Each
consumer then takes the synced script, with its prose repairs in the same
change.

## Citations

- Implements: none. The sentence unit does not exist yet.
- Extends: STE-RULES
- Extends: STE-SCOPE

This change adds one unit to [spec/ste-lint.md](../../spec/ste-lint.md) for the
sentence rules. It amends STE-RULES-1, so a sentence rule can exist beside the
three tables. It amends STE-RULES-3, so a sentence finding names the rule
"sentence length" with the count and the limit. It amends STE-RULES-6, so the
sentence rule reports one finding for each sentence. A line can then carry more
than one sentence finding. It adds a rule to STE-SCOPE for the `--file` option.
The new rule states that the caller chooses the file, and that STE-SCOPE-1 and
STE-SCOPE-2 govern the scope walk only. The `Extends:` form comes from pull
request 26 of this repository. It sets each register row in the same change.
This plan names no new rule number, because a number exists only after the rule
lands.

## Decisions

The operator approved these on 2026-09-08. This change must not reverse one
without approval.

| #   | Decision                                                                                                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | The two sentence limits are machine rules. The review panel does not report them.                                                     |
| 2   | A sentence rule is a fourth mechanism of `ste-lint`, beside the word table, the phrase table, and the pattern table.                  |
| 3   | `--file PATH` scans the named files only, with the fence and span exemptions of the scope rules. The option repeats.                  |
| 4   | A consumer takes the new script and its prose repairs in one change. A gate that fails on `main` must not sit there.                  |
| 5   | A rule for the word "can" in a prohibition stays out of this plan. No expression of it holds every correct sentence, per STE-RULES-4. |

## Evidence

An audit of 72 sessions measured each claim below on 2026-09-08.

### The panel does the linter work

A hand-classified sample of 40 reviewer finding lines held four writing-standard
findings, 12 percent of the real findings. Two examples follow. "This 49-word
sentence breaks the 25-word limit of the writing standard, and about 65 more
sentences across the five plans do the same". "The instruction 'Append a rule to
LRN-DELIVER: ...' runs 49 words, above the 20-word instruction limit and the
25-word descriptive limit". Three reviewers at high effort found these at 60k to
215k tokens each.

### The fixes reintroduce the defect

The main session of the seven-round merge wrote at round five: "A few of the
round-four rewrites reintroduced sentences over the limit." At round one it
wrote: "32 sentences exceed 25 words, mostly enumerations. I'll split them with
a whitespace-tolerant edit script". The scan existed for one session and died
with it.

### The script has three tables and one scope

`org/sync/scripts/ste-lint` holds `@WORDS`, `@PHRASES` and `@PATTERNS`, and it
compiles each entry into a line rule. It reads one line at a time, so a sentence
that wraps across two lines has no rule that can see it. The script takes
`--root DIR` only. The passive-voice rule exists already, at the pattern
`passive voice "%s"`.

### The Markdown wraps at 80 columns

The formatter wraps each paragraph and each list item at 80 columns. A sentence
of 25 words spans two or three lines. A sentence rule must join the lines of a
block before it counts.

## Design

### The block

A block is a paragraph or a list item. A blank line, a heading, a table row, a
fence line, a new list marker, or the end of the file ends a block. The scanner
joins the lines of a block with one space. It skips a heading, a table row, a
fenced code block, YAML front matter, and an HTML comment. A blockquote stays in
scope.

### The sentence

The scanner splits a block at a sentence end. A sentence end is a period or a
question mark, an optional closing quotation mark or parenthesis, and then
whitespace or the block end. The scanner replaces each inline code span with one
placeholder word before the split. A period inside a span then does not end a
sentence, and a span counts as one word. It drops a link target and keeps the
link text. A word is one whitespace-separated token that holds a letter or a
digit, so a dash counts as none.

### The two limits

An instruction sentence starts with a word of a new table `@IMPERATIVES`, the
imperative verbs of the repository prose. Examples are `Run`, `Read`, `Write`,
`Add`, `Delete`, `Set`, `Use`, `Keep`, `Put`, `Move`, `Commit`, `Push`,
`Report`, `Return`, `Launch`, `Dispatch`, `Repeat`, `Stop`, `Do`, and `Never`.
The table holds the verb in its imperative form only. An instruction sentence
must hold fewer than 20 words. Every other sentence must hold fewer than 25
words.

A finding names the file, the first line of the sentence, and the rule "sentence
length". It holds the word count, the limit, and the first 60 characters of the
sentence. The finding joins the count of STE-RULES-5, and the run exits
non-zero. A block can hold more than one sentence finding.

### The single-file mode

`--file PATH` names one file. The option repeats. With one `--file` or more, the
scanner reads those files only, and it skips the scope walk. Every rule runs on
each named file: the word table, the phrase table, the pattern table, and the
sentence rules. Each file gets the fence exemption and the span exemption. A
path is absolute or relative to the working directory. A hook calls
`ste-lint --file <path>`, and an agent can call it on the file it edits.

### The tests

`perl/t/ste-lint.t` gains these fixtures:

- A 26-word sentence that wraps across two lines gives one finding.
- A 25-word descriptive sentence gives one finding, and a 24-word one gives
  none.
- A 20-word instruction gives one finding, and a 19-word one gives none.
- A table row of 30 words gives none.
- A heading of 30 words gives none.
- A 30-word line in YAML front matter gives none.
- A 30-word HTML comment gives none.
- A 26-word sentence in a blockquote gives one finding.
- A sentence whose span holds a period gives one sentence.
- Two quoted sentences split at the period before the closing quotation mark. A
  sentence that ends inside a parenthesis splits at the period before the
  closing parenthesis.
- A period inside a link target does not split.
- `--file` on a fixture outside the scope reports the finding. The same fixture
  inside the scope reports the same finding under a root scan.
- A repeated `--file` scans both files.

### The rollout

The new rules find sentences in every consumer today. Each consumer takes the
synced script and its prose repairs in one change, per decision 4. The workspace
holds the rollout record.

## Work

- `org/sync/scripts/ste-lint`: the block scanner, the sentence split, the
  imperative table, the two limits, and `--file`.
- `perl/t/ste-lint.t`: the fixtures of the Tests section.
- `spec/ste-lint.md`: the sentence unit, the STE-RULES-1, STE-RULES-3 and
  STE-RULES-6 amendments, and the `--file` rule under STE-SCOPE.
- `spec/STATUS.md`: the rows.
- `org/sync/CLAUDE.md`: the writing-standard line names the sentence rules
  beside the banned words and patterns.
- The root copy of `CLAUDE.md` lands by hand, because `scripts/sync` refuses to
  run inside Tooling. `perl/t/org.t` holds each root copy to the canon.
- Delete this plan.

## Status

### What lands now

Every item of the Work section lands now, in this repository. The repository
prose of Tooling passes the new rules before the change merges.

### What waits

The consumer repairs wait for the sync of each consumer.

REV-AGENTS-4 of `spec/review.md` tells the reviewer to skip a defect that
`make check` catches. The panel then stops its sentence-length findings. The
lint hook of the review panel waits for a measured pilot. This plan supplies its
`--file` mode.

### Open questions

1. The imperative table decides which sentence gets the 20-word limit. The first
   table comes from the verbs in the rule files of this repository. A verb that
   the table misses gets the 25-word limit, so a miss is safe.
