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
- **SYNC-PACKS-8** — The `python` pack must live at `python/sync/` and must
  serve the consumers with Python code. It holds the shared Ruff configuration
  `ruff.toml` and the make fragment `mk/python.mk`. It also holds the Python
  style rules, at `packages/CLAUDE.md` of the consumer, and the consumer test
  `t/ci/python.t`. The consumer keeps `pyproject.toml`, `.python-version`, and
  `uv.lock`, per SYNC-IDENTITY.

<a id="sync-identity"></a>

## Identity

- **SYNC-IDENTITY-1** — A synced file must not carry repository identity.
- **SYNC-IDENTITY-2** — Consumer identity must live in `.toolingrc` and in the
  consumer README.
- **SYNC-IDENTITY-3** — The synced root `CLAUDE.md` must import the consumer
  README with an `@README.md` line.
- **SYNC-IDENTITY-4** — A Perl consumer can name the perl floor of its
  distribution under `dist.perl` in `.toolingrc`, in the form `5.0NN`. The dist
  build must stamp that floor into the generated `Makefile.PL` and `META.json`,
  and must refuse a value outside that form. The default is `5.036`.

<a id="sync-marker"></a>

## The marker

- **SYNC-MARKER-1** — Every synced file must start with a marker comment. The
  marker text is: "The `<pack>` pack of FuguBSD/Tooling owns this file. Do not
  edit a synced copy. Edit the canonical copy in FuguBSD/Tooling."
- **SYNC-MARKER-2** — In a file with `#` comment syntax, the marker must use `#`
  comment lines. In a Markdown or HTML file, the marker must use one HTML
  comment.
- **SYNC-MARKER-3** — Only a shebang line, an `ex:` editor hint, YAML front
  matter, and blank lines can come before the marker.
- **SYNC-MARKER-4** — A file without comment syntax, an empty placeholder file,
  and a file that GitHub copies into user content carry no marker. The exempt
  files are `.prettierrc` (JSON), `plans/.gitkeep` (empty), and
  `.github/pull_request_template.md` (each pull request body receives a copy).
- **SYNC-MARKER-5** — The test `perl/t/marker.t` must hold every pack file to
  this unit.

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
  dispatcher and of each included pack fragment. It must also hold a copy of
  each pack configuration that the root gates read. Each copy must equal the
  canon byte for byte.

<a id="sync-bootstrap"></a>

## Bootstrap constraint

- **SYNC-BOOTSTRAP-1** — `scripts/sync` and the synced scripts `deps`, `ftp`,
  `spec-check`, and `ste-lint` must use core modules and `use v5.34` only. They
  run before any dependency install, and macOS ships perl 5.34.
- **SYNC-BOOTSTRAP-2** — `scripts/deps` must find `ftp` as an executable
  sibling. The two files move together, and the exec bit matters.

<a id="sync-alias"></a>

## The platform aliases

A release asset spells one platform in more than one way. The gitleaks release
names the x86_64 architecture `x64`, and the gh release names Darwin `macOS`. A
manifest must hold neither word.

- **SYNC-ALIAS-1** — A manifest must write `{os}` and `{arch}` in place of a
  platform word. `scripts/deps` must expand both, in the URL and in the archive
  path.
- **SYNC-ALIAS-2** — The script must hold an alias table for each word. It must
  form one candidate URL for each alias pair. The table must not hold two
  spellings that one host answers alike, because both would download the same
  bytes.
- **SYNC-ALIAS-3** — The script must take the candidate that `deps/SHA256.txt`
  names. No match and more than one match are each an error. The match is the
  whole URL, so each candidate carries its own line.
- **SYNC-ALIAS-4** — The resolution must not ask the network.
- **SYNC-ALIAS-5** — An entry with a placeholder needs a recorded digest,
  because the resolution reads the digest file. The signify tier serves an entry
  without a placeholder only.
- **SYNC-ALIAS-6** — Each placeholder of the archive path must also sit in the
  URL. The digest file names the URL, and not the path inside the archive. A
  word that only the archive path holds has nothing to select it.

<a id="sync-download"></a>

## The download check

`scripts/deps` downloads a file for a `bin` entry and for a `dist` entry. Each
download gets a check before it reaches the install directory.

The two tiers key their digests apart. `deps/SHA256.txt` gathers many upstreams,
so it keys on the download URL. Two entries can therefore end in one file name,
and each entry still keeps its own line and its own tier. The signed manifest of
a release covers one release directory. That directory holds unique file names,
so the manifest keys on the file name.

- **SYNC-DOWNLOAD-1** — Each download must land in a temporary directory. The
  script must check the bytes before it extracts an archive, and before a file
  reaches `~/.local/bin`.
- **SYNC-DOWNLOAD-2** — A failed check must stop the install. It must leave the
  install directory as it was.
- **SYNC-DOWNLOAD-3** — `deps/SHA256.txt` must record a sha256 digest for each
  download with a versioned name. The key is the download URL, and the format is
  `SHA256 (url) = hexdigest`.
- **SYNC-DOWNLOAD-4** — A bad line, a digest that is not 64 hexadecimal
  characters, and a duplicate URL are each an error.
- **SYNC-DOWNLOAD-5** — With no recorded digest, the script must derive `SHA256`
  and `SHA256.sig` from the directory of the download URL. It must verify the
  signature before it downloads the file. The directory must hold no
  placeholder, so the alias words expand first.
- **SYNC-DOWNLOAD-6** — The signed manifest must name the file. The script must
  then hold the file to the digest of that manifest. The key there is the file
  name, because the manifest covers one release directory.
- **SYNC-DOWNLOAD-7** — An entry with no recorded digest and no signature must
  stop the install. The cpanm bootstrap is the one exception, because no
  manifest names it. A repository avoids it with a cpanminus package in its
  `tool` environment.
- **SYNC-DOWNLOAD-20** — The cpanm bootstrap must download the standalone
  `cpanm` script and run it with the current perl. It must not install
  `App::cpanminus`. `cpanm` with no root and no `local::lib` writes to the local
  library of the user. `PATH` does not hold the `cpanm` it lands there.
- **SYNC-DOWNLOAD-8** — The script must run `signify(1)` as a command, and it
  must accept the name `signify-openbsd`. It must not load `Fugu::Signify`,
  because a `dist` entry installs that module.
- **SYNC-DOWNLOAD-9** — `scripts/ftp` must exit non-zero on an HTTP error, and
  it must leave no file.
- **SYNC-DOWNLOAD-10** — A command name becomes a file name in the install
  directory, so it must hold no path. An archive path must hold no empty and no
  parent segment. Neither may start with a dash, which `tar` and `unzip` read as
  an option.
- **SYNC-DOWNLOAD-11** — The check of SYNC-DOWNLOAD-10 must run over every line
  of the manifest, and again after the alias words expand.
- **SYNC-DOWNLOAD-12** — A download URL must name a file, and the URL must hold
  no parenthesis and no space. The line format of `deps/SHA256.txt` reserves
  both, and that file keys on the whole URL. The check must run over every line
  of the manifest. `--update-sums` must check each candidate as well, because a
  candidate becomes a line of the file.
- **SYNC-DOWNLOAD-13** — A `pkg` name and a `cpan` name must not start with a
  dash, and neither may be a URL. Both reach a package manager, which owns its
  own check.
- **SYNC-DOWNLOAD-16** — A digest mismatch must name the repair of its own tier.
  A recorded digest takes `--update-sums --force`, and a signed digest takes a
  report to the upstream.
- **SYNC-DOWNLOAD-17** — A message that stops an install must name the command
  that repairs it, when one exists.
- **SYNC-DOWNLOAD-18** — A digest file key must hold a scheme. An older file
  keys on the file name. Such a line must stop the install, and the message must
  name the repair.
- **SYNC-DOWNLOAD-19** — `deps --update-sums` must drop a file-name key when it
  records the URL that replaces it, and it must report each drop. One run reads
  one manifest, so a key that the run cannot replace must stay. A blanket drop
  would unpin every other platform.

A signature over a stable name binds no version. A server that answers the URL
can therefore replay an earlier signed release. A consumer that must not take an
earlier release names a versioned URL and a recorded digest.

<a id="sync-sums"></a>

## The digest refresh

`deps --update-sums` records a digest in `deps/SHA256.txt`. The operator runs
it, and the install path must not.

- **SYNC-SUMS-1** — The command must record the digest of each versioned
  download. It must keep a URL that the file already holds.
- **SYNC-SUMS-2** — A versioned name carries a digit in the path of its URL. The
  file name alone is not the test, because a release can carry its version in a
  directory.
- **SYNC-SUMS-3** — The command must skip a stable name, and it must read the
  manifest for that test. A server that withholds its signature must not make
  the command pin the bytes that it serves.
- **SYNC-SUMS-4** — An entry with a placeholder is never a stable name, because
  the resolution reads the digest file.
- **SYNC-SUMS-5** — The command must not record a digest of its own download for
  a URL that a signed manifest sits beside. Such a digest would outrank the
  signature, and this command authenticates no download.
- **SYNC-SUMS-6** — The signed-manifest test must not need `signify(1)`, and it
  must fail closed. A server that answers the manifest and withholds the
  signature must not make the command record a digest.
- **SYNC-SUMS-7** — An entry with a placeholder needs a recorded digest, and a
  signed manifest beside its URL must supply that digest. A manifest that names
  no candidate must stop the entry.
- **SYNC-SUMS-8** — `--force` must rewrite a recorded digest, and it must pin a
  stable name. It must drop every other candidate URL of the same entry.
- **SYNC-SUMS-9** — `--force` must override the signed-manifest test, and it
  must warn first. An upstream that publishes a manifest the operator cannot
  verify would otherwise leave the entry unpinnable. The override must cover a
  manifest that no key verifies, and a manifest that names no candidate.
- **SYNC-SUMS-10** — Each candidate must download to its own directory. Two
  candidates can share a file name, and one path would hold the bytes of the
  last download.
- **SYNC-SUMS-11** — A run that records nothing must leave the digest file as it
  was, and it must say so.
- **SYNC-SUMS-12** — The command must report a recorded URL only when it writes
  the file. A failed run must name a next step.
- **SYNC-SUMS-13** — `--force` must belong to `--update-sums`. An install run
  must reject it.
- **SYNC-SUMS-14** — The signed-manifest test must ask a resolved directory, and
  never the directory of the manifest template. A placeholder in the directory
  gives each candidate its own directory, and an unresolved probe finds no
  manifest.
- **SYNC-SUMS-15** — The test must ask each distinct directory until one gives a
  candidate. A verified manifest that names no candidate must not hide a later
  directory that holds the release.
- **SYNC-SUMS-16** — An entry that reaches no candidate must fail the run. The
  command must not report success for a state that makes the next install fail.
  An entry with a placeholder and no recorded digest is such a state.

<a id="sync-keys"></a>

## The signify keys

- **SYNC-KEYS-1** — The org pack owns `deps/KEYS.txt`. A consumer pins a
  third-party key in `deps/KEYS.local.txt`, and sync must not touch that file.
- **SYNC-KEYS-2** — A key line holds a name and then one of two forms. Two
  fields give the key body, and three fields give a URL and a sha256 digest.
- **SYNC-KEYS-3** — The key body must be 56 base64 characters. It must decode to
  42 bytes with the prefix `Ed`.
- **SYNC-KEYS-4** — The URL form must hold the downloaded key file to the
  recorded digest. A rotation must not change a published URL.
- **SYNC-KEYS-5** — The line order is the trust order, and the current key comes
  first.
- **SYNC-KEYS-6** — A key file with no key line is valid. The signify tier must
  then stop with an error that names the empty key set.
- **SYNC-KEYS-7** — A key name must hold letters, digits, a dot, a dash and an
  underscore only. The name becomes a file name in a temporary directory.
- **SYNC-KEYS-8** — A key name must appear one time. A repeated name would
  shadow the second key and break the trust order.
- **SYNC-KEYS-9** — A key that fails its digest, or that no server answers, must
  not stop the trust order. The script must try the next key, and it must report
  each failure when no key verifies.
- **SYNC-KEYS-10** — No key binds to one entry, so every declared key verifies
  every signify-tier download. A consumer must pin a key in
  `deps/KEYS.local.txt` only when it trusts that key for each entry of its
  manifests.
