# The sync mechanism

The `scripts/sync` script copies the canonical shared files into a consumer
repository. This document specifies the packs, the identity rule, the
verification, and the bootstrap constraint.

<a id="sync-packs"></a>

## Packs

A pack is one sync tree of this repository. A consumer receives the union of its
packs, each file at the same relative path.

- **SYNC-PACKS-1** — The `org` pack must live at `org/sync/` and must serve
  every consumer.
- **SYNC-PACKS-2** — The `perl` pack must live at `perl/sync/` and must serve
  the Perl consumers.
- **SYNC-PACKS-3** — A consumer must select its packs with `sync.pack` lines in
  `.toolingrc`.
- **SYNC-PACKS-4** — With no `sync.pack` line, sync must deliver the `org` pack
  only.
- **SYNC-PACKS-5** — A relative path must not exist in two packs.
- **SYNC-PACKS-6** — The `infra` pack must live at `infra/sync/` and must serve
  the consumers with OpenTofu code. It holds the shared infrastructure
  instructions, at `infra/CLAUDE.md` of the consumer.
- **SYNC-PACKS-7** — The `web` pack must live at `web/sync/` and must serve the
  consumers with a fuguweb site. It holds the shared website instructions, at
  `web/CLAUDE.md` of the consumer. It also holds the shared footer, at
  `web/footer.body.html` of the consumer.

<a id="sync-identity"></a>

## Identity

- **SYNC-IDENTITY-1** — A synced file must not carry repository identity.
- **SYNC-IDENTITY-2** — Consumer identity must live in `.toolingrc` and in the
  consumer README.
- **SYNC-IDENTITY-3** — The synced root `CLAUDE.md` must import the consumer
  README with an `@README.md` line.

<a id="sync-check"></a>

## Verification

- **SYNC-CHECK-1** — `sync --check` must report a missing file, a content
  difference, and an exec-bit difference, and must change nothing.
- **SYNC-CHECK-2** — The CI of a consumer must run `sync --check` as a drift
  gate.
- **SYNC-CHECK-3** — The root copies of the org files in this repository must
  equal the canon byte for byte. `scripts/` and `t/` have no root copies: the
  scripts run in place, and the tests serve the consumers.
- **SYNC-CHECK-4** — The root of this repository must hold a copy of the
  dispatcher and of each included pack fragment. Each copy must equal the canon
  byte for byte.

<a id="sync-bootstrap"></a>

## Bootstrap constraint

- **SYNC-BOOTSTRAP-1** — `scripts/sync` and the synced scripts `deps`, `ftp`,
  `spec-check`, and `ste-lint` must use core modules and `use v5.34` only. They
  run before any dependency install, and macOS ships perl 5.34.
- **SYNC-BOOTSTRAP-2** — `scripts/deps` must find `ftp` as an executable
  sibling. The two files move together, and the exec bit matters.
