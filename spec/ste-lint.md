# The prose lint

The synced `scripts/ste-lint` rejects prose that breaks the ASD-STE100 writing
standard, and the common marks of machine-generated prose. Every consumer runs
it in `make check`. This document specifies the scan scope and the rule design.
The bootstrap constraint of [sync.md](sync.md#sync-bootstrap) applies to the
script.

<a id="ste-scope"></a>

## Scope

- **STE-SCOPE-1** — The lint must scan the Markdown files of the repository root
  and of `spec/` at the first level. It must also scan `.github/`, `.claude/`,
  `lib/`, `plans/`, and `t/` with their subdirectories.
- **STE-SCOPE-2** — The lint must not scan `docs/`, a `spec/` subdirectory, a
  root scratch file with a `SCRATCHPAD` name prefix, or `.claude/worktrees/`. A
  worktree is a separate checkout.
- **STE-SCOPE-3** — A code fence and an inline code span are exempt.
- **STE-SCOPE-4** — The `--root DIR` option must select the repository root. The
  default root is the parent of the script directory.

<a id="ste-rules"></a>

## Rules

- **STE-RULES-1** — Three tables must hold the rules. `@WORDS` holds one banned
  word per entry. `@PHRASES` holds one banned word sequence per entry.
  `@PATTERNS` holds one labeled regular expression per entry. One rule is one
  entry in one table.
- **STE-RULES-2** — A word and a phrase must match in any letter case. A phrase
  must match its words in order, across the whitespace of one line.
- **STE-RULES-3** — A finding must name the file, the line, and the rule. When
  the rule expression has a capture group, the finding must hold the captured
  text.
- **STE-RULES-4** — The tables must hold no word that correct technical prose
  needs. A repair changes the prose, and must not remove a rule.
- **STE-RULES-5** — With one finding or more, the lint must report the count and
  exit non-zero.
- **STE-RULES-6** — The word rule must report each match on a line. Each other
  rule must report at most one finding for each line.
