# The specification check

The synced `scripts/spec-check` validates the specification documents, the
implementation register, and the plans of a repository. Every consumer runs it
in `make check`. This document specifies the scan scope and each rule. The
bootstrap constraint of [sync.md](sync.md#sync-bootstrap) applies to the script.
The synced `spec/CLAUDE.md` holds the citation forms for the author, and this
document states what the check rejects.

<a id="spc-scope"></a>

## Scope

- **SPC-SCOPE-1** — The check must scan `CLAUDE.md` and `README.md` of the
  repository root. It must also scan the Markdown files of `spec/`, `docs/`, and
  `plans/`, with their subdirectories. The plan rules read a `plan.md` in a
  subdirectory of `plans/` only.
- **SPC-SCOPE-2** — A fenced code block is exempt from each rule that reads a
  scanned file. SPC-DOCS-1 reads the raw text of `spec/index.md`. SPC-CITE-2
  reads the text without the fences, and it resolves each token against the raw
  text of `spec/DECISIONS.md`. A fence therefore hides no link of
  `spec/index.md`, and no ID of `spec/DECISIONS.md`.
- **SPC-SCOPE-3** — An inline code span is exempt from SPC-CITE-1 and
  SPC-CITE-2. The plan rules take the code marks off a citation, and read the
  text under them.
- **SPC-SCOPE-4** — The `--root DIR` option must select the repository root. The
  default root is the parent of the script directory. The check must stop with
  an error when the root holds no `spec` directory.
- **SPC-SCOPE-5** — The `--drift BASE` option must turn the drift gate on. Each
  other rule must run in both modes.
- **SPC-SCOPE-6** — With one error or more, the check must report each error and
  the count, and it must exit non-zero. Without an error, it must report the
  count of the documents, the units, and the rules.

<a id="spc-links"></a>

## Links

- **SPC-LINKS-1** — Each relative link of a scanned file must point to a path
  that exists. A link with a URL scheme is exempt.
- **SPC-LINKS-2** — Each fragment of a relative link to a Markdown file must
  resolve. A heading slug and an HTML anchor of the target document each resolve
  a fragment.

<a id="spc-docs"></a>

## Documents

- **SPC-DOCS-1** — `spec/index.md` must link each document of `spec/` at the
  first level, except `index.md` and `CLAUDE.md`.
- **SPC-DOCS-2** — The document table of `spec/index.md` must name at least one
  code, and each document that the table lists must exist.
- **SPC-DOCS-3** — `spec/index.md`, `spec/ROADMAP.md`, `spec/DECISIONS.md`, and
  `spec/STATUS.md` must each exist.
- **SPC-DOCS-4** — A specification document must not name a schedule phase. The
  governance documents are exempt: `index.md`, `CLAUDE.md`, `DECISIONS.md`,
  `ROADMAP.md`, and `STATUS.md`.

<a id="spc-units"></a>

## Units and rules

- **SPC-UNITS-1** — Each unit anchor must sit in the document of its code, and
  each unit anchor must be unique. An anchor that starts with no document code
  is not a unit anchor.
- **SPC-UNITS-2** — Each rule definition must sit in the document of its unit,
  and each rule ID must be unique.

<a id="spc-register"></a>

## The register

- **SPC-REGISTER-1** — `spec/STATUS.md` must hold a Units table under a Units
  heading, with the columns Unit, State, Done by, and Note.
- **SPC-REGISTER-2** — The register must hold one row for each unit anchor, and
  one row only. It must hold no row without a unit anchor. Each Unit cell must
  hold one link to the unit anchor. Each row must hold four cells.
- **SPC-REGISTER-3** — Each row must name one state of the fixed vocabulary:
  `open`, `partial`, `done`, or `n-a`. Each "Done by" value must name a phase ID
  of the [roadmap](ROADMAP.md) table or an em dash.
- **SPC-REGISTER-4** — A `partial` row must hold a note. A `done` row must hold
  at least one relative link. Each such link must point to a path that exists.
- **SPC-REGISTER-5** — A retired ID must hold no unit anchor and no register
  row.

<a id="spc-cite"></a>

## Citations

- **SPC-CITE-1** — Each unit token and each rule token must resolve. A unit
  anchor, a rule definition, and a retired ID each resolve a token. The scan
  covers `CLAUDE.md`, `README.md`, `spec/` at the first level, and `plans/`.
- **SPC-CITE-2** — Each decision token of `spec/` at the first level must
  resolve to an ID of `spec/DECISIONS.md`.
- **SPC-CITE-3** — A token that the name of a sibling repository precedes is
  exempt from SPC-CITE-1 and SPC-CITE-2. A subdirectory of `spec/` and the
  `docs/` tree hold reference material, and they are exempt too.

<a id="spc-plans"></a>

## Plans

- **SPC-PLANS-1** — The check must reject a verb that holds no citation text on
  its line. It must reject a citation that runs into the next verb.
- **SPC-PLANS-2** — Each unit under `Implements:` or `Extends:` must exist, and
  a plan must not cite a `done` unit under `Implements:`.
- **SPC-PLANS-3** — A unit under `Extends:` must be `done`. A rule ID and a
  `without` clause are each an error under `Extends:`.
- **SPC-PLANS-4** — A unit under `Defers:` must not sit under `Implements:` or
  under `Extends:` in the same plan. The rule compares the unit tokens of the
  whole plan, and it holds no state between two plans. The rule compares a known
  unit only, because SPC-PLANS-2 rejects an unknown one. A `without` clause
  leaves the unit token in place, and a rule ID alone is no match.

<a id="spc-drift"></a>

## The drift gate

- **SPC-DRIFT-1** — With `--drift BASE`, the gate reads the files that changed
  since the merge base with `BASE`. It looks at each document that holds an
  implemented unit. A `partial` unit and a `done` unit are each implemented.
- **SPC-DRIFT-2** — A change to such a document must also change
  `spec/STATUS.md` or a code root of that document. The gate must read the Code
  roots table of `spec/STATUS.md`. A document with no row there has no root, and
  an em dash names no root.
