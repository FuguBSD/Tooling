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
- **STE-SCOPE-5** — The `--file PATH` option must name one file, and it can
  repeat. With one option or more, the lint must scan the named files only, and
  it must skip the scope walk. The caller picks the file, so STE-SCOPE-1 and
  STE-SCOPE-2 govern the scope walk only. STE-SCOPE-3 must hold for a named
  file. The lint must reject a path that names no readable Markdown file. It
  must reject it before it reports the first finding.

<a id="ste-rules"></a>

## Rules

- **STE-RULES-1** — Three tables must hold the table rules. `@WORDS` holds one
  banned word per entry. `@PHRASES` holds one banned word sequence per entry.
  `@PATTERNS` holds one labeled regular expression per entry. One table rule is
  one entry in one table. The sentence rules of [Sentences](#ste-sentence) stand
  beside the three tables.
- **STE-RULES-2** — A word and a phrase must match in any letter case. A phrase
  must match its words in order, across the whitespace of one line.
- **STE-RULES-3** — A finding must name the file, the line, and the rule. When
  the rule expression has a capture group, the finding must hold the captured
  text. A sentence finding must name the rule `sentence length`. It must hold
  the word count, the greatest correct count, and the first 60 characters.
- **STE-RULES-4** — The tables must hold no word that correct technical prose
  needs. A repair changes the prose, and must not remove a rule.
- **STE-RULES-5** — With one finding or more, the lint must report the count and
  exit non-zero.
- **STE-RULES-6** — The word rule must report each match on a line. A sentence
  rule must report one finding for each sentence over its limit, so one line can
  carry more than one. Each other rule must report at most one finding for each
  line.

<a id="ste-sentence"></a>

## Sentences

The writing standard sets a word limit for a sentence. The formatter wraps a
paragraph at 80 columns, so a sentence spans two lines or three. The lint joins
the lines of a block before it counts the words.

- **STE-SENTENCE-1** — The lint must count the words of each sentence. An
  instruction sentence must hold fewer than 20 words. Every other sentence must
  hold fewer than 25 words.
- **STE-SENTENCE-2** — A block is one paragraph or one list item. The lint must
  join the lines of one block with one space. A blank line, a heading, a table
  row, or a fence line ends a block. An indented code block, a new list marker,
  or the end of the file ends one too.
- **STE-SENTENCE-3** — A fenced code block, an indented code block, a table row,
  a heading, YAML front matter, and an HTML comment hold no sentence. A setext
  heading holds no sentence, and its underline drops the block above it. A
  blockquote and a list item stay in scope, and a blockquote marker holds one
  space of its own.
- **STE-SENTENCE-4** — A sentence ends at a period or a question mark. A run of
  closing marks can follow it: a quotation mark, a parenthesis, a bracket, or an
  emphasis mark. Whitespace or the block end must follow. A run of two periods
  or more ends no sentence. An abbreviation of the `@ABBREVIATIONS` table ends
  none either. That table must hold an abbreviation that never ends a sentence,
  and no other.
- **STE-SENTENCE-5** — The lint must replace each inline code span with one
  placeholder word, and must drop each link target. A period inside a span or a
  target then ends no sentence.
- **STE-SENTENCE-6** — A word is one whitespace-separated token that holds a
  letter or a digit. A list marker and a blockquote marker count as no word.
- **STE-SENTENCE-7** — An instruction sentence starts with a word of the
  `@IMPERATIVES` table. The table must hold the imperative form of a verb, or a
  word that leads a negative instruction. A sentence that starts outside the
  table takes the 25-word limit, so a word outside the table is safe.
- **STE-SENTENCE-8** — A noun can spell an imperative verb, so a table word can
  head a descriptive sentence. No imperative verb takes `of`, a modal, or a form
  of `be` with a subject next. One of those words after a table word must give
  the 25-word limit. The bare `be` stays out, because `Never be ...` is an
  instruction. No imperative verb takes a second finite verb next. A table word
  with an `s` after a table word must give the 25-word limit too. A second word
  that holds no letter names no verb, so it must give the 25-word limit.
- **STE-SENTENCE-9** — A list item and a blockquote both indent their own text.
  An indented code block inside one must start four columns further right. A
  line above that column is a continuation, and it stays in scope.
