# 012 — ste-lint learns the dialect, and every repository repairs its prose

## Status

The operator authorized this plan on 2026-09-23 to describe work that every
FuguBSD repository implements. The Location rule of `plans/CLAUDE.md` gives a
plan one repository. This plan overrides that rule for the lint rollout alone.
The lint lives here, the rules land here, and each repair package below names
the repository that implements it. A second rule of the operator shapes the
plan: a class of findings with a large count is a repair list. It is never a
reason to drop the rule.

Work packages 1 to 5 land here, in that order, and each can start now. Work
package 6 adds the pack trees of this repository to the walk, and it repairs
them. It waits on work packages 1 and 3. Each repository package of work package
7 waits on work package 6 and on a sync of the pack.

- Extends: STE-RULES. The implementation adds a name exemption to STE-RULES-2,
  and it adds one rule for the label of a Latin abbreviation.
- Extends: STE-SENTENCE. The implementation adds a paragraph rule and the POD
  reader rules. It drops the bold lead from the word count of STE-SENTENCE-6,
  and it removes the `@ABBREVIATIONS` table from STE-SENTENCE-4.
- Extends: STE-SCOPE. The implementation adds the `--dir` option and the `.pod`
  file to the walk and to the `--file` check of STE-SCOPE-5. It adds `docs/` and
  `spec/` with their subdirectories to the walk of STE-SCOPE-1. It removes the
  two from the exempt set of STE-SCOPE-2.
- Extends: MK-VERBS. The implementation adds `ste-lint-man` to the plain
  targets, and it names `mandoc` as the program of the target.
- Extends: MK-COMPOSE. The implementation adds `ste-lint-man` to the gate list
  of MK-COMPOSE-5, and it adds `MANDOC` and `STE_LINT_MAN` to the variables of
  `mk/org.mk`.

## Purpose

The lint has run in every consumer since 2026-08-26. Four sources name what it
misses. They are the 1505 session traces, the prose audit of thirteen
repositories, and two web surveys. The surveys cover the published tells of
Claude prose and the detector tooling. The plan adds every rule with a source
behind it. It then repairs every finding in every repository, in the Markdown,
the POD, and the manual pages.

The scratch reports live in the workspace under `scratch/ste-audit/`. They are
`traces.md`, `prose-A.md` to `prose-D.md`, `web-claude-tells.md`,
`web-rule-sets.md` and `web-claude-technical.md`. A prototype of the full rule
set, `ste-lint-next`, sits beside them, and the counts below come from it.

## Scope

In scope:

- The rule tables, the `@IMPERATIVES` table, and the `@ABBREVIATIONS` table of
  `org/sync/scripts/ste-lint`.
- The word rule, the sentence rule, a paragraph rule, and the POD reader.
- The scope walk, the `--dir` option, and the exempt set.
- A manual-page script and target of the org pack, and an HTML target of
  Website.
- The prose repair of the twelve projects, the workspace, and the library.
- The units STE-SCOPE, STE-RULES, STE-SENTENCE, MK-VERBS and MK-COMPOSE, and the
  tests `perl/t/ste-lint.t`, `perl/t/man-lint.t` and `perl/t/org.t`.

Out of scope:

- A glossary rule. One term for `remove` and `delete` is a specification gap of
  each project, and a lint rule is not a glossary.
- A restatement scan and a dangling-reference scan. Both belong to `spec-check`,
  and a plan of its own must carry them.
- A gate on the library. FuguBSD LIB-LIBRARY-5 bans a format gate, and the
  library CI reports. The repair of the library still merges, in work package 7.

## What the tree says

The measurements below come from the traces and the checkouts, on 2026-09-22 and
2026-09-23. A finding count comes from `ste-lint-next`, the prototype of the
full rule set, over the scope walk of each checkout.

**Sentence length is the whole lint today.** 898 of 1105 trace findings are
sentence findings. The median overshoot is 3 words. 188 findings start with a
bold rule ID, and the ID counts as words today. Of 30 sampled repairs, 24 split
the sentence well, one left `These files` with no antecedent, and one dropped
`in the same change` from a rule.

**The word rule moved one tell instead of removing it.** All 20 repairs of
`Thus` swapped in `So`. The corpus holds 31 sentence-initial `So` and
`Therefore` in scope.

**The word rule has no exemption for a name.** `Foster` fired seven times on a
citation, `Excel` once, and `enhanced` on the term `enhanced dependencies`.

**The passive rule catches one passive in five.** The rule needs `by`. The
traces hold 14 real catches, and the current prose holds 55 passives without
`by`.

**The published tells mostly miss this corpus.** The web survey ranks five
shapes first, by 12 to 22 sources each. They are negative parallelism, the rule
of three, the em-dash pivot, the participial tail, and copula avoidance. The
tables hold four of the five. The chat moves, the hedge stacks and `genuinely`
have zero hits in scope.

**The dialect has shapes that a word table cannot hold.** One published rule
set, `vale-ai-tells`, names the negated object. That is a verb with `no` moved
onto its object, as in `The host needs no installed program`. It measured its
verb list against 1.3 million lines of human documentation. The corpus holds 307
lines of that shape in scope. The other shapes are grammatical, and their
density is the fingerprint. The prototype counts them below.

**The full rule set reports 1883 findings in scope, over fourteen checkouts.**
The table names each rule with 25 findings or more.

| Rule                                   | Findings |
| -------------------------------------- | -------: |
| banned word, `lands` and `would` first |      290 |
| causal clause `, so the`               |      369 |
| negated object                         |      307 |
| balanced clause `, and the X does`     |      157 |
| colon assertion                        |       98 |
| prohibition without `must not`         |       80 |
| tail negation `, not Y`                |       69 |
| semicolon join                         |       60 |
| relative clause `, which`              |       55 |
| em-dash inside a sentence              |       53 |
| sentence length, all in the library    |       43 |
| banned phrase                          |       37 |
| connective `So` and `Therefore`        |       31 |
| sentence tail `too`                    |       30 |
| negation chain                         |       25 |

**The exempt trees hold 2088 more.** FuguTTX `docs/` holds 1584, FuguPass
`docs/` 247, Fugu `spec/protocol/` 157, and FuguOracle `docs/` 100. The other
projects hold no exempt Markdown.

**The POD and the manual pages hold about 1600 more.** The `.pod` sidecars of
Fugu, FuguVM and FuguWeb report 655, 290 and 282 findings under the prototype,
with the directive lines stripped. Five of the eleven manual pages report 184
through `mandoc -T markdown`, with one SYNOPSIS false positive per page.

**The pack trees of this repository hold 56.** Each `*/sync` tree is out of the
lint walk here, and in scope in every consumer. A defect in the pack surfaces in
twelve checkouts. The fix is one commit here.

**No agent worked around the lint. The operator names length.** The traces show
zero edits to a synced copy, zero moves into `docs/`, and zero escapes into a
heading or a table. Seventeen operator turns correct prose, and they say "less
is more", "don't be louder", and "as brief as an OpenBSD manual".

## Constraints that shape the design

**A count is a repair list.** The operator set the rule on 2026-09-23. A rule
with a source merges, and its findings get a repair. The size of the class
changes the order of the packages, and it changes nothing else.

**One criterion keeps a word out.** STE-RULES-4 stands: the tables hold no word
that correct technical prose needs. That keeps `verdict` out, because a FuguCTX
repair pair carries a verdict. It keeps `clean` out, because `fuguweb clean` is
a verb of the program. It keeps `owns` out, because no source names it, and
because SYNC-MARKER-1 writes it in every synced file. It keeps `gate` out,
because `make check` runs gates. It keeps `proper` out, because `proper noun` is
a grammar term.

**One topic per sentence.** The standard sets that rule, and it backs the clause
rules. A sentence of the form "X does A, and Y does B" holds two topics. A
sentence of the form "X holds A, so Y does B" holds a cause and an effect. Each
becomes two sentences, or one sentence with `because`.

**Negate the verb, or state the fact.** A negated object hides a negative
statement in a positive sentence. `The host needs no installed program` becomes
`The host does not need an installed program`, or
`The host runs the shim with base tools alone`. The second form is shorter, and
it is the preferred repair.

**Fix the prose, never the tables.** The name exemption changes the match. A
repair changes the prose. No word leaves a table for a repair.

**A fact outlives its repair.** The trace study found two repairs that dropped a
fact. A repair keeps every requirement, every cross-reference, and every
antecedent. A split at `because` keeps the cause with the rule.

**A record keeps its facts and its dates.** The `docs/research/` notes are dated
records. The repair changes their prose. It keeps each date, each number, and
each finding.

**The word count follows the standard.** A rule ID and a bold lead are a label,
and the count drops the lead.

**One tool reads prose.** POD is prose with a directive line, a verbatim block,
and a formatting code, and the reader gains those three marks. A manual page
renders through `mandoc`, and a script of the org pack feeds the lint. An HTML
body renders through a tag strip, and a make target of Website feeds the lint.
The lint itself reads Markdown and POD, and nothing else.

**Core perl, v5.34.** The bootstrap constraint of SYNC-BOOTSTRAP holds.

## The interface contract

The lint gains one option. `--dir DIR` adds one directory tree to the scope
walk, and it can repeat. The walk reads each `.md` file and each `.pod` file.
`--file` still skips the walk. It accepts a `.md` path and a `.pod` path, and it
rejects any other path before the first finding.

The walk gains two trees. It enters `docs/` and `spec/` with their
subdirectories, as it enters `plans/` today. The exempt set loses the two
entries. A root scratch file with a `SCRATCHPAD` name prefix and
`.claude/worktrees/` stay exempt.

The lint reads a `.pod` file. A directive line starts with `=`. It ends a block,
and the lint drops it. The lint skips the text from a `=begin` line to its
`=end` line. It also skips a `=for` line and the paragraph that follows it. A
`=cut` line closes the POD, and the lint skips the text after it until the next
directive line. A formatting code such as `C<...>`, `F<...>`, `L<...>`, `B<...>`
or `I<...>` becomes one placeholder word. An indented block is free of prose, as
STE-SENTENCE-3 says.

The finding format of STE-RULES-3 holds. A paragraph finding names the rule
`paragraph length`, the sentence count, and the greatest correct count.

`mk/local.mk` of this repository sets
`STE_LINT = org/sync/scripts/ste-lint --root . $(SYNC_DIRS)`. `SYNC_DIRS` lists
one `--dir` for each of the five pack trees, `infra/sync`, `org/sync`,
`perl/sync`, `python/sync` and `web/sync`. The list is explicit, because
MK-SUBSET-2 bans a GNU function in the file. A new pack adds one entry.

The org pack gains the script `scripts/ste-lint-man` and the target
`ste-lint-man`. The script is POSIX shell with the marker of SYNC-MARKER-1. It
lists each `*.[1-9]` page that `git ls-files` reports, in any directory. With no
page, it prints nothing and exits with status zero, before the `mandoc` check
and the lint. Without `mandoc`, it dies with the program name. It renders each
page with `mandoc -T markdown`, and it drops the SYNOPSIS section. It writes the
result to `build/man-md/<page>.md`, with the tracked path of the page as
`<page>`. The org `.gitignore` names `build/`. MK-VERBS-1 lets a read target
write a gitignored path. The script then runs the `ste-lint` of its own
directory with `--file` over the written files. The target is one recipe line
that calls the script, per MK-SUBSET-3. `make check` of every consumer runs it.
`MANDOC` names the program, with the default `mandoc`. The recipe passes it to
the script in the environment. `STE_LINT_MAN` names the script, with the default
`scripts/ste-lint-man`. `mk/local.mk` of this repository points it into
`org/sync/scripts/`, as it does for `STE_LINT`.

`mandoc` comes from the deps manifest. A repository that holds a page names
`tool pkg mandoc` in `deps/Linux.txt`. `make deps` then installs it, per
MK-DEPS-4. macOS and OpenBSD ship `mandoc` in the base system. Their manifests
stay. The check workflow of such a repository runs `make deps` before
`make ste-lint-man`, as the gitleaks job does. This repository also names it,
because `perl/t/man-lint.t` renders a fixture page.

Website gains the target `ste-lint-html`. It strips the tags of each body file
into `build/html-md/`, and it runs `ste-lint --file` over the result.

The new rules read as follows. A plan omits the rule number, because the number
exists after the rule merges.

- A rule of STE-RULES: "A word that starts with a capital letter after a word in
  lower case is a name. The word rule must not report it. A word at the start of
  a sentence, or after a list marker, is no name."
- A rule of STE-RULES: "A Latin abbreviation finding must name the rule
  `Latin abbreviation` and hold the abbreviation."
- A rule of STE-SENTENCE: "A block must hold at most six sentences. The lint
  must report one finding for each block over the limit."
- A change of STE-SENTENCE-6: "The word count skips a bold lead at the start of
  a block, and one dash after it."
- A change of STE-SENTENCE-4: the sentence about the `@ABBREVIATIONS` table
  leaves the rule.
- A rule of STE-SENTENCE: "A POD directive line ends a block. The lint must skip
  the directive line. It must skip the text from a `=begin` line to its `=end`
  line, and a `=for` line with its paragraph. It must skip the text after a
  `=cut` line, up to the next directive line. It must replace each POD
  formatting code with one placeholder word."
- A rule of STE-SCOPE: "The `--dir DIR` option must add one directory tree to
  the scope walk, and it can repeat."
- A change of STE-SCOPE-1: "The lint must scan each `.md` file and each `.pod`
  file of the repository root. It must also scan `.github/`, `.claude/`,
  `docs/`, `lib/`, `plans/`, `spec/`, and `t/` with their subdirectories."
- A change of STE-SCOPE-5: "The `--file` path must name a readable `.md` file or
  a readable `.pod` file. The lint must reject any other path before it reports
  the first finding."
- A change of STE-SCOPE-2: `docs/` and the `spec/` subdirectory leave the exempt
  set.

## Work packages

### WP1 — The tables gain every rule with a source

The package can start now. Each entry names its prototype count.

1. Add these words to `@WORDS`, in the group that fits each. Present tense:
   `would` (46). Modal: `may` (6), `should`, `might` (0 each). Requirement:
   `necessary` (7). Programmer idiom: `gracefully` (6), `cleanly` (4), `loudly`
   (3), `silently` (2), `deliberately` (5). Figurative state: `quiet` (8),
   `quietly` (1), `cheap` (10), `expensive` (1), `honest` (8), `survives`,
   `survived` (7), `settles`, `settled` (1). Plan vocabulary with a measured
   Claude rate: `lands` (120). Vague quantity: `many` (16), `several` (9). Vague
   qualifier: `sufficient` (2), `appropriate`, `relevant`, `suitable`,
   `adequate` (0 each). Hedge adverb: `typically`, `generally`, `usually`,
   `normally`, `basically`, `obviously`, `clearly` (1 together). Marketing:
   `ecosystem` (4), `first-class` (3), `idiomatic` (1), `trivial` (0). Anthropic
   bans in its own prompts: `genuinely`, `honestly`, `actually` (0).
   Preposition: `via` (15). Jargon: `gating`, `belt-and-suspenders` (0).
2. Add these phrases to `@PHRASES`. Openers: `there is`, `there are` (12).
   Reframing: `rather than`, `which means`, `whether or not`. Meta: `note that`,
   `in other words`, `in short`, `in practice` (1), `on paper` (8), `in theory`,
   `under the hood`, `out of the box`, `at a high level`, `bottom line`,
   `net effect`, `it is worth`, `worth stating`, `the honest answer`,
   `full stop` (1). Vague: `edge case`, `a few` (15). Modal: `needs to`,
   `ought to`, `is recommended`.
3. Add the sixteen patterns of the block below to `@PATTERNS`. The comment on
   each line names the prototype count in scope.

   ```perl
   [ qr/,\s+which\b/i, 'relative clause ", which"' ],                                  # 55
   [ qr/(?:^|[.?]\s+)(So|Therefore),?\s+[a-z]/, 'connective "%s"' ],                   # 31
   [ qr/\b(too|as well|either)[.,;]/i, 'sentence tail "%s"' ],                        # 30
   [ qr/(?:^|\.\s+)This (ensures|means|allows|guarantees|keeps|makes|gives|lets|enables)\b/,
       'meta opener "This %s"' ],                                                      # 3
   [ qr/\b(e\.g\.|i\.e\.|etc\.)/i, 'Latin abbreviation "%s"' ],                       # 2
   [ qr/\b((?!(?:has|have|contains|takes|returns|finds|matches|sees|is|was|does)\b)[a-z]+(?:s|es)\s+(?:no|zero)\s+(?!(?:longer|one|more|less|matter)\b)[a-z]+)/i,
       'negated object "%s"' ],                                                        # 307
   [ qr/\bno\s+\w+(?:\s+\w+)?,\s+(?:and\s+)?no\s+\w+/i, 'negation chain' ],           # 25
   [ qr/(?:^|\.\s+)((?:Two|Three|Four|Five|Six|Several)\s+\w+\s+(?:belong|matter|follow|remain|stand|shape|drive|decide|govern))\b/,
       'cataphoric count "%s"' ],                                                      # 2
   [ qr/(?:^|[.?]\s+)(?:The|One|A|An|Each|Every|That|This|Its|No|Both)\s[^:.?]{2,50}:\s[a-z]/,
       'colon assertion' ],                                                            # 98
   [ qr/\w;\s+\w/, 'semicolon join' ],                                                 # 60
   [ qr/,\s+not\s+(?:a|an|the|its|their|one|every|for|of|in|on|to|by|as)?\s*[\w-]+(?:\s[\w-]+){0,3}\.(?:\s|$)/,
       'tail negation ", not"' ],                                                      # 69
   [ qr/^(?!\s*(?:[-*+]|\d+\.)\s+\*\*[^*]+\*\*\s+\x{2014})(?!\s*#)(?!\s*\|).*\S\s+\x{2014}\s+\S/,
       'em-dash inside a sentence' ],                                                  # 53
   [ qr/\b((?:must|can|cannot)\s+(?:not\s+)?be\s+(?:\w+ly\s+)?(?!(?:done|set|fixed|lost|spent|un\w+)\b)(?:\w{3,}ed|built|drawn|found|given|held|kept|known|left|made|met|put|read|run|seen|sent|shown|split|taken|told|written))\b/i,
       'modal passive "%s"' ],                                                         # 6
   [ qr/\bmust\s+\w+\s+no\b|\bmay not\b/i, 'prohibition without "must not"' ],        # 80
   [ qr/,\s+and\s+(?:the|a|an|its|each|every|no|one)\s+\w+\s+(?:is|are|holds|names|takes|gives|runs|has|does|stays|carries|reads|owns|keeps|sets|goes|must|can)\b/i,
       'balanced clause ", and the X does"' ],                                         # 157
   [ qr/,\s+so\s+(?:the|a|an|it|each|every|no|one|this|its)\b/i,
       'causal clause ", so the"' ],                                                   # 369
   ```

4. Delete the `@ABBREVIATIONS` table, the `$ABBREVIATION` join, and the
   exemption line of `_sentences`. Remove the sentence from STE-SENTENCE-4.
5. Add the verbs of the skills to `@IMPERATIVES`. The list is below.

   ```
   squash confirm reject make open rebase test retire record quote
   close drop cite ask show list count measure compare install build
   print save load fetch mark archive tag release publish retry negate
   strip render
   ```

6. Repair the prose of this repository outside the pack trees, per the Repair
   rules section.
7. Add one test for each entry, per the Tests section.

Acceptance:

- `make check` passes.
- Each new test fails against the script of `main`.
- `git grep -n ABBREVIATION org/sync/scripts/ste-lint` reports nothing.

### WP2 — The word rule and the sentence rule learn the label and the name

The package can start now.

1. Add the name exemption to the word rule. A match whose first letter is a
   capital, after a token in lower case on the same line, is no finding. A match
   at the start of the line, after a list marker, after a period, or after a
   bold mark stays a finding.
2. Drop the bold lead from the word count. A block that starts with `**...**`,
   and one `—` or `-` after it, counts the words after the dash. The sentence
   text of the finding keeps the lead.
3. Add the paragraph rule to `_sentence_findings`. A block with more than six
   sentences reports `paragraph length: N sentences, max 6` on its first line.
4. Add the three rules to `spec/ste-lint.md`, and change STE-SENTENCE-6.
5. Add the tests, per the Tests section.

Acceptance:

- `make check` passes.
- `Wagner and Foster, EMNLP 2021` passes, and `Thus the tool runs.` fails.
- A rule item of 26 words with a five-word bold lead passes.
- A block of seven one-word sentences fails, and one of six passes.

### WP3 — The walk reads every tree and every POD file

The package can start now.

1. Add the `--dir DIR` option. Each value joins the walk list beside `.github`,
   `.claude`, `lib`, `plans` and `t`. A value without a directory dies before
   the first finding, as STE-SCOPE-5 does for a file.
2. Add `docs` and `spec` to the walk list of `_files`. Delete the first-level
   read of `spec/`. The walk then enters each subdirectory of the two trees.
3. Add `.pod` to the file filter of the walk and to the target check of
   `--file`. The check dies with `not a Markdown file` today. After the change
   it accepts a `.md` path and a `.pod` path, and it rejects any other path.
4. Add the POD reader to `_blocks` and `_line_findings`. A line that starts with
   `=` ends the block, and the reader drops it. The reader skips the text from a
   `=begin` line to its `=end` line. It skips a `=for` line with its paragraph.
   It skips the text after a `=cut` line, up to the next directive line. A
   formatting code `[A-Z]<...>`, with one nesting level and the `<<...>>` form,
   becomes the word `code`.
5. Change STE-SCOPE-1, STE-SCOPE-2 and STE-SCOPE-5, add the `--dir` rule and the
   POD rule, and add the tests.

Acceptance:

- `make check` passes.
- A banned word under `docs/` and under `spec/protocol/` fails.
- A banned word under `extra/` fails with `--dir extra`, and passes without it.
- `--file lib/Example.pod` scans the file, and `--file README.txt` dies before a
  finding.
- `lib/Example.pod` with a 30-word sentence fails. The same text passes between
  `=begin` and `=end`, after a `=for` line, and after `=cut`.
  `The C<open> call returns a handle.` counts five words.

### WP4 — The org pack lints the manual pages

The package can start now. It waits on nothing. Every consumer takes it with its
sync.

1. Add the script `org/sync/scripts/ste-lint-man`, in POSIX shell, with the
   marker of SYNC-MARKER-1 and the exec bit. The script lists each page with
   `git ls-files '*.[1-9]'`. FuguOracle holds its pages at the root, FuguPass
   under `src/*/`, and the perl projects under `man/`. With no page, the script
   prints nothing and exits with status zero. It then checks `$MANDOC`, with the
   fallback `mandoc`, and it dies with the program name when the check fails.
2. For each page, the script runs `$MANDOC -T markdown` and drops the lines from
   the `# SYNOPSIS` heading to the next heading. It writes the result to
   `build/man-md/<page>.md`. It then runs the `ste-lint` of its own directory
   with `--file` over the written files, and it exits with the lint status.
3. Add the variables `MANDOC ?= mandoc` and
   `STE_LINT_MAN ?= scripts/ste-lint-man` to `org/sync/mk/org.mk`. Add the
   target `ste-lint-man` with the one recipe line
   `@MANDOC="$(MANDOC)" $(STE_LINT_MAN)`, per MK-SUBSET-3. Add the target to
   `CHECK_TARGETS` and to `.PHONY`. Set
   `STE_LINT_MAN = org/sync/scripts/ste-lint-man` in `mk/local.mk`, because the
   canonical scripts run in place here.
4. Add `perl/t/man-lint.t`. It runs the script over a fixture page with a
   30-word sentence in DESCRIPTION and a 61-word SYNOPSIS, and it asserts one
   finding. It runs the script in an empty temporary repository, and it asserts
   an empty output and the exit status zero. Add `ste-lint-man` to the `sh -n`
   parse check of `perl/t/org.t`.
5. Name `tool pkg mandoc` in `deps/Linux.txt` of this repository, because the
   test renders a page. macOS and OpenBSD ship `mandoc` in the base system, and
   `deps/Darwin.txt` stays. The `test` job installs the `tool` environment
   through `make deps-test`, per MK-DEPS-2.
6. Document the script and the target in `spec/make.md`. Add `ste-lint-man` to
   the plain-target list of MK-VERBS and to the gate list of MK-COMPOSE-5. Add
   `MANDOC` and `STE_LINT_MAN` to the variables of `mk/org.mk` under MK-COMPOSE.
   State that a repository with a page names `tool pkg mandoc` in
   `deps/Linux.txt`, per MK-DEPS-4.

Acceptance:

- `make check` passes here, and `perl/t/man-lint.t` fails against `main`.
- `make -n ste-lint-man` prints one line.
- On a host without `mandoc`, the script dies with the program name.
- `make deps` installs `mandoc` on Linux, and the target passes after it.
- A consumer without a page passes the target without `mandoc`, with no output.

### WP5 — Website lints its HTML bodies

The package can start now. Website implements it, under the authorization of
this plan.

1. Add the target `ste-lint-html` to the Website makefile. For each
   `web/*.body.html`, strip each tag with `sed 's/<[^>]*>//g'`, and write
   `build/html-md/<name>.md`.
2. Run `$(STE_LINT) --file` over the written files, and add the target to the
   check targets of Website.
3. Measure the findings, and record the count in the commit message.

Acceptance:

- `make check` of Website runs the target.
- A body file with a banned word fails the target.

### WP6 — The pack trees join the walk and repair their prose

The package waits on work packages 1 and 3. The 56 findings of the `*/sync`
trees surface in every consumer. The fix is one commit here.

1. Set `SYNC_DIRS` in `mk/local.mk` to one `--dir` for each pack tree of the
   contract. Add it to `STE_LINT`.
2. Run `make check` with the hook, and list each finding of a `*/sync` tree.
3. Repair each one, per the Repair rules section. The plan vocabulary of
   `org/sync/plans/CLAUDE.md` changes `lands` to `merges`.
4. Repair the ten-sentence block of
   `org/sync/.claude/skills/review-panel/SKILL.md`, the ten-sentence block of
   `perl/sync/lib/CLAUDE.md`, and the eight-sentence block of
   `org/sync/spec/CLAUDE.md`. Prefer a removal.
5. Commit, and merge with `merge-it`.

Acceptance:

- `make check` passes here, with the five `*/sync` trees in the walk.
- A banned word under `org/sync/` fails `make check`.
- After a sync, every pack file of a consumer passes the lint.

### WP7 — Each repository repairs its prose

One package for each repository, and each waits on work package 6. The table
names the order, the repository, and the prototype count of each tree. The order
puts the pack owner first, then the small consumers, then the large ones. A
small consumer proves the rollout before a large repair starts.

| Order | Repository   | Scope | Exempt trees | POD | Manual pages |
| ----: | ------------ | ----: | -----------: | --: | -----------: |
|     1 | Tooling      |   192 |            0 |   0 |            0 |
|     2 | Website      |    43 |            0 |   0 |            0 |
|     3 | FuguVM       |    54 |            0 | 290 |       1 page |
|     4 | Repositories |    54 |            0 |   0 |            0 |
|     5 | FuguCTX      |    60 |            0 |   0 |            0 |
|     6 | FuguOracle   |    97 |          100 |   0 |      2 pages |
|     7 | FuguSeed     |   111 |            0 |   0 |      3 pages |
|     8 | FuguWeb      |   117 |            0 | 282 |       1 page |
|     9 | Workspace    |   128 |            0 |   0 |            0 |
|    10 | Library      |   128 |            0 |   0 |            0 |
|    11 | Fugu         |   139 |          157 | 655 |            0 |
|    12 | FuguSTX      |   158 |            0 |   0 |            0 |
|    13 | FuguPass     |   300 |          247 |   0 |      4 pages |
|    14 | FuguTTX      |   302 |         1584 |   0 |            0 |

The `ste-lint-man` script of the org pack reaches each page of the table,
because it lists the pages with `git ls-files`. The root pages of FuguOracle and
the `src/*/` pages of FuguPass count with the `man/` pages of the perl projects.

The steps of one package:

1. Sync the pack, and run `make check </dev/null`.
2. In a repository with a page, name `tool pkg mandoc` in `deps/Linux.txt`, and
   run `make deps`. Add `make deps` before `make ste-lint-man` in the check
   workflow, as the gitleaks job does.
3. List each finding, grouped by rule.
4. Repair each finding, per the Repair rules section. Repair the pack-owned
   copies by a sync, never by hand.
5. Run `make check` again, and read each changed rule sentence against its code.
   A repair that changes a requirement is a defect.
6. Commit in groups. Give the specification, the plans, the instruction files,
   the POD, and the manual pages one commit each.
7. Merge with `merge-it`. A repair is a patch-level change.
8. Trim the row of this table in the same change, per `plans/CLAUDE.md`.

Acceptance, for each repository:

- `make check` passes with the synced pack.
- `git diff --stat main` names prose files alone, and no test changes. The deps
  manifest and the check workflow of a repository with a page are the exception.
- The register `spec/STATUS.md` holds the same states before and after.

The library has no lint gate, per FuguBSD LIB-LIBRARY-5. Its package runs the
lint by hand with `--root`, and it repairs the 128 findings. The session pages
and the library pages keep every claim, every number, and every date.

## Repair rules

Each package of work package 6 and work package 7 follows these rules. The trace
study wrote them from the repairs that went wrong.

- Keep every fact. A requirement, a cross-reference, a number, and a date
  survive the repair. Read the sentence after the repair against the code or the
  log that it describes.
- Keep the cause with the rule. A split at `because` puts the cause in the
  sentence that holds the requirement, or in the sentence right after it.
- Keep the antecedent. A sentence that starts with `These`, `It`, `They` or
  `That` after a split must name its subject.
- Negate the verb, or state the positive fact. `The tool holds no state` becomes
  `The tool is stateless` or `The tool does not hold state`.
- Split a two-topic sentence. "X does A, and Y does B" becomes two sentences. "X
  holds A, so Y does B" becomes two sentences, or "Y does B because X holds A".
- Replace a colon assertion with a sentence. "The tier is empty: the daemon
  needs core Perl only" becomes "The tier is empty. The daemon needs core Perl
  only".
- Drop the tail negation. "Write the page for the visitor, not for the
  maintainer" becomes "Write the page for the visitor".
- Replace `lands` with `merges`, and `a few` with a count.
- Prefer a removal to a rewrite. The operator says "less is more".
- Never change a rule ID, a command, a code example, or a technical name.

## Tests

`perl/t/ste-lint.t` gains one test for each entry and each rule. Each test holds
the fixture that fails and the sibling that passes, and each new assertion must
fail against the script of `main`. The tests must assert:

- Each new word and phrase fails, with its label.
- `, which` fails, and `Which file?` passes.
- `So the tool runs.` fails, and `so the tool runs` after a comma passes.
- `The tool runs too.` fails, and `The tool is too slow.` passes.
- `e.g.` fails with the label `Latin abbreviation`, and a sentence that ends at
  `e.g.` splits at the period.
- `needs no installed program` fails, `takes no argument` passes, and
  `has no step` passes. `requires zero configuration` fails.
- `no step, no schedule, and no name` fails once, and `no step and one name`
  passes.
- `Three caveats belong at the front.` fails, and `Three files exist.` passes.
- `The tier is empty: the daemon needs core Perl only.` fails, and a table row
  with a colon passes.
- `The tool runs; the daemon waits.` fails, and a semicolon inside a code span
  passes.
- `Write the page for the visitor, not for the maintainer.` fails, and
  `The tool does not run.` passes.
- `The tool — a shim — runs.` fails, and `- **ID-1** — text` passes.
- `The file must be statically linked.` fails, and `The layout is fixed.`
  passes.
- `The command must hold no threshold.` fails, and
  `The command must not hold a threshold.` passes.
- `The spec holds the design, and the plan holds the steps.` fails, and
  `the spec, the plan, and the code` passes.
- `The shell resets, so the tool names the directory.` fails, and `so that`
  passes.
- `Wagner and Foster, EMNLP 2021` passes, and `Thus the tool runs.` fails.
  `- Thus the tool runs.` fails after the list marker.
- A 26-word rule item with a five-word bold lead passes, and a 26-word item with
  no lead fails.
- A block of seven sentences fails with `paragraph length`, and a list of seven
  one-sentence items passes.
- A banned word under `docs/` and under `spec/protocol/` fails.
- `--dir extra` scans the tree, and `--dir missing` dies before a finding.
- `--file lib/Example.pod` scans the file, and `--file README.txt` dies before a
  finding.
- A `.pod` file fails on a long sentence, and it counts a formatting code as one
  word. The same sentence passes on a directive line, between `=begin` and
  `=end`, after a `=for` line, and after `=cut`.

`perl/t/man-lint.t` runs `ste-lint-man`. It must assert:

- A fixture page with a 30-word sentence in DESCRIPTION and a 61-word SYNOPSIS
  reports one finding.
- With no page, the script prints nothing and exits with status zero.
- Without `mandoc`, the script dies with the program name.

## What this repository cannot prove

The green state of a consumer needs the `make check` of that consumer, with its
own tests and its own pack. Each package of work package 7 proves it there.

The counts above are one measurement of one day, from a prototype. The real
count at sync time differs. The pack repair of work package 6 removes the
copies. The mechanics of work package 2 change the sentence findings.

The HTML count of Website is unmeasured. Work package 5 measures it.

## Rollback

Each table entry is one line, and a revert of the line removes the rule. Each
mechanism of work package 2 and work package 3 merges in one commit, and one
revert removes it. Work package 4 merges in one commit, with the script, the
target, the test and the specification text. One revert removes the four. A
consumer drops the script and the target at its next sync.

A consumer that finds a rule wrong pins the earlier pack in its own change. It
reports the finding here, with the sentence that the rule hit. The rule then
gains an exclusion with a test, or the word leaves the table under STE-RULES-4.

A repair commit of work package 7 reverts on its own. The commit groups of step
6 keep a revert small.

## Open questions

1. The library gate. FuguBSD LIB-LIBRARY-3 makes the library CI report, and
   LIB-LIBRARY-5 bans a format gate. This plan repairs the library and keeps the
   gate a report. A change of that decision is a workspace decision, and the
   operator makes it.
2. The word `owns` has 166 hits, and SYNC-MARKER-1 writes it in every synced
   file. No source names it as a tell. It stays out under STE-RULES-4 today. A
   later source can bring it in, with a change of the marker text.
3. The house verbs `holds` (716), `names` (422) and `carries` (123) are approved
   words of the standard. A density rule cannot see one line. The plan records
   the count without a rule.
4. The bold lead with a period, `**Sentence.** text`, is the designed lead of a
   plan paragraph and of a library claim. It has 157 hits. No source names it.
   It stays.
5. The stacked declarative, `The X holds Y. The Z names W.`, needs a rhythm
   measure over a block. The paragraph rule of work package 2 is the first block
   rule, and a rhythm rule can follow it in a later plan.
6. The `docs/research/` notes of FuguTTX hold 1584 findings. The repair changes
   their prose and keeps their facts. The operator accepted that cost on
   2026-09-23.
