# 003 — Verified dependency installs

`scripts/deps` downloads a binary and installs it without a check of the bytes.
It expands one architecture word and one operating system word, so a release
asset with a different spelling needs a hardcoded workaround in the manifest.
This plan adds two guarantees to the org pack. Each downloaded file must match a
recorded sha256 digest, or a signify signature. Each download URL must resolve
through an alias table, so no manifest holds a hardcoded platform word.

The plan also makes one install path for gitleaks. The manifest provides the
binary in a new `tool` environment, and the operator and CI both install it with
`make deps`. The `setup-gitleaks` action stays until each consumer drops it.

The org pack owns `scripts/deps`, `scripts/ftp` and `mk/org.mk`, so this
repository lands the change first. Each consumer then takes the synced files.
The workspace holds the organization record of the whole rollout.

## Citations

Implements: none. The design units do not exist yet.

This change adds one unit to [spec/make.md](../../spec/make.md) for the
environments and the deps targets. It adds three units to
[spec/sync.md](../../spec/sync.md) for the alias resolution, the verification
tiers, and the key file. It amends MK-VERBS-4, MK-GITLEAKS-4 and
SYNC-BOOTSTRAP-1, and it sets each register row in the same change. This plan
names no new rule number, because a number exists only after the rule lands.

## Decisions

The operator made these decisions for the organization. This change must not
reverse one without approval.

| #   | Decision                                                                                                                                   |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Alias resolution reads the digest manifest. The install path must not probe the network. An ambiguous match is an error.                   |
| 2   | Each entry that downloads a URL must carry a sha256 digest, or a signify signature. Neither one present is an error.                       |
| 3   | The digests live in `deps/SHA256.txt`, in BSD format, keyed by file name.                                                                  |
| 4   | A new `tool` environment installs before every other environment. A `tool` entry must not use the signify tier.                            |
| 5   | `scripts/deps` derives the signature URLs from the download URL base, so the signify tier stays generic.                                   |
| 6   | The release key lives online, as a GitHub organization secret. A workflow of the Website repository rotates it.                            |
| 7   | The rule MK-GITLEAKS-4 changes, so a manifest can provide gitleaks.                                                                        |
| 8   | `deps/KEYS.txt` declares each signify public key, as the key body or as a URL and sha256 pair. `deps/KEYS.local.txt` holds a consumer key. |
| 9   | The `setup-gitleaks` action retires. Each check workflow installs gitleaks with `make deps`, from the manifest.                            |

Decision 4 fits the fixed target names of D-08. `make deps` runs the `tool`
environment and then the `runtime` environment, so no `deps-tool` target exists.

## Evidence

This session measured each claim below on 2026-09-06.

### The fetcher accepts an error page

`scripts/ftp` runs `curl -L -o` on Darwin, with no `-f` option. A measured 404
exits 0 and writes a 9-byte body that holds the text `Not Found`. The same URL
with `-f` exits 22 and writes no file. The Linux branch runs `wget -O`, which
exits 8 and leaves an empty file.

`scripts/deps` downloads a plain `bin` entry straight into
`~/.local/bin/<name>`. A failed download therefore replaces a working binary
with a broken file. An archive entry downloads into a temporary directory first.

### A tool line is invisible today

`_read_manifest` validates the type word of each line, and it skips a line whose
environment word does not match the wanted environment. It does not reject an
unknown environment word. A measured run of `deps --dry-run --os Linux runtime`
against a manifest with a `tool bin gitleaks ...` line installed nothing for
that line, and it reported success.

A consumer that moves gitleaks to the `tool` environment before this change
therefore loses the binary of its secret gate, with no message. The order of the
rollout depends on this fact.

### Two hardcoded platform words exist today

| Consumer manifest              | Hardcoded word                    | Cause                                 |
| ------------------------------ | --------------------------------- | ------------------------------------- |
| `Repositories/deps/Darwin.txt` | `gh_2.97.0_macOS_{arch}.zip`      | The `{os}` expansion gives `darwin`.  |
| `Workspace/deps/Linux.txt`     | `gitleaks_8.30.1_{os}_x64.tar.gz` | The `{arch}` expansion gives `amd64`. |

The release assets confirm both causes. The gitleaks release holds no
`linux_amd64` asset at all, and the gh release holds no `darwin` asset at all.

### The entries that download a URL

Only a `bin` entry and a `dist` entry download a URL. A `pkg` entry and a `cpan`
entry pass the name to apt, brew, pkg_add or cpanm, and those tools own their
own integrity check.

### The setup-gitleaks action is the second install path

The action installs `gitleaks_8.30.1_linux_x64.tar.gz` and checks it against the
sha256 default
`551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb`
(WFL-GITLEAKS-1). That digest seeds the first `deps/SHA256.txt` entry.

The action appends `$HOME/.local/bin` to `GITHUB_PATH`. `scripts/deps` installs
into the same directory and appends nothing. The default PATH of the Ubuntu
runner holds `/home/runner/.local/bin`, and this change confirms that before it
drops the append.

### The synced workflow test rejects a make deps step

`org/sync/t/ci/workflows.t` fails a workflow line that matches `make deps`, with
the message "runs no deps target of its own". The rule assumes that the
setup-perl action owns every install. A check workflow without that action, as
in the workspace, therefore cannot install gitleaks from its manifest until this
test changes.

### The setup-perl action fixes the environment words

The action accepts `runtime`, `test` or `develop` as its `dependencies` input,
and it rejects every other word. It maps `runtime` to `make deps`, and the other
two to `make deps-<name>`. D-08 fixes the three target names. A `tool`
environment therefore cannot get a target of its own, and it must run inside
`make deps`.

### The bootstrap constraint holds

SYNC-BOOTSTRAP-1 limits the synced scripts to core modules and `use v5.34`.
`scripts/deps` also runs before any dependency exists, and the Fugu distribution
arrives through a `dist` line. `scripts/deps` therefore must not load
`Fugu::Signify`. It runs `signify(1)` as a command, and it computes a digest
with the core module `Digest::SHA`. The duplication is deliberate, and the
specification must record the reason.

### The deps test runs without the network

`perl/t/deps.t` runs the script under `--dry-run` and `--os` against fixture
manifests. It never fetches a file. The new tiers verify bytes, so a dry run
cannot cover them. `scripts/deps` finds `ftp` as an executable sibling
(SYNC-BOOTSTRAP-2), so a test can place a stub `ftp` beside a copy of the
script. The stub copies a fixture file, and the test then drives each tier and
each error path.

### Sync carries a new pack file with no change

`scripts/sync` walks the whole pack tree and copies each file to the same path
in the consumer. A new `org/sync/deps/KEYS.txt` therefore reaches each consumer
with no change to the script. Each synced file must start with a marker comment
(SYNC-MARKER-1), so the key file starts with `#` lines, and the parser must skip
them. A consumer without a `deps/` directory gets one that holds the key file
only.

## Design

### The tool environment

The environment words become `tool`, `runtime`, `test` and `develop`. The `deps`
target of `mk/org.mk` runs `$(DEPS) tool` and then `$(DEPS) runtime`.
`deps-test` and `deps-develop` chain over `deps`, as they do today, so `tool`
installs one time in each chain. No `deps-tool` target exists.

`scripts/deps` must reject an unknown environment word in a manifest line, as it
rejects an unknown type word. A silent skip hides a typo, and the evidence shows
the cost.

A `tool` entry must not use the signify tier, because that tier needs
`signify(1)`. A project whose platform lacks the command adds a `tool` entry for
it, as `tool pkg signify-openbsd` on Linux. OpenBSD holds the command in base.
Only a repository with a signify-tier entry needs the `tool` entry.

### Alias resolution

`scripts/deps` holds a table of aliases for the operating system word and for
the architecture word. The candidate set is the cross product of the two lists.

- The architecture `x86_64` gives `amd64`, `x64` and `x86_64`.
- The architecture `aarch64` and `arm64` give `arm64` and `aarch64`.
- The operating system `Darwin` gives `darwin`, `macOS`, `macos` and `osx`.
- The operating system `Linux` gives `linux`, and `OpenBSD` gives `openbsd`.

The script forms one file name for each candidate. It then selects the candidate
that `deps/SHA256.txt` names. No match is an error, and two matches are an
error. The install path makes no request to find the URL.

One selected pair expands both the URL and the member path of an entry. An entry
with a placeholder therefore needs a digest entry, because the resolution reads
the digest file. The signify tier serves an entry without a placeholder only.
The specification must state this limit.

### The digest manifest

`deps/SHA256.txt` holds one line for each downloaded file, in BSD format. One
file serves every operating system and every architecture, because the asset
names differ already. A bad line, a digest that is not 64 hexadecimal
characters, and a duplicate name are each an error.

    SHA256 (gitleaks_8.30.1_linux_x64.tar.gz) = 551f6f...

A stable-name asset, such as `releases/latest/download/Fugu.tar.gz`, must not
appear in the file. Its bytes change with each release, and a recorded digest
breaks at the next release. Such an asset uses the signify tier.

### The key file

`deps/KEYS.txt` declares each signify public key. The org pack owns the file,
and sync copies it to each consumer. A consumer adds a third-party key to
`deps/KEYS.local.txt`, which sync must not touch. That split copies MK-LOCAL-1.

A line holds a name and then one of two forms. The body form gives the key body
as one word. The URL form gives the URL of the key file and the sha256 digest of
that file. Both forms are valid in both files, and one file can mix them.

The field count selects the form. Two fields give the body form, and the body
must be 56 base64 characters that decode to 42 bytes with the prefix `Ed`. Three
fields give the URL form, and the digest must be 64 hexadecimal characters. Any
other count is an error that names the line. A line that starts with `#` is a
comment, so the file can carry the sync marker. The line order is the trust
order, so the current key comes first.

The URL form fetches the key file into a temporary directory, and it compares
the digest against the line. A mismatch is an error that names the key. The
digest is the trust anchor, and a rotation must not change a published URL.

The organization holds no published release key yet, so this change ships the
file with the marker, the format comments, and no key line. The parser must
accept a file with no key line. The signify tier must then stop with an error
that names the empty key set. The Website repository adds the first key line
when it publishes the first key.

### The verification tiers

For each `bin` entry and each `dist` entry, `scripts/deps` runs this order.

1. A `deps/SHA256.txt` entry for the resolved file name gives the digest. The
   script downloads the file and compares the digest.
2. With no such entry, the script derives `SHA256` and `SHA256.sig` from the
   directory part of the download URL. It downloads the pair, verifies the
   signature against the keys of `deps/KEYS.txt`, and then verifies the file
   against the signed manifest. The manifest must name the resolved file name.
   The script verifies the signature before it downloads the file.
3. With neither one, the script stops with an error.

Every download lands in a temporary directory. The script verifies the bytes
before it extracts an archive, and before any file reaches `~/.local/bin`. A
failure removes the temporary directory and leaves the install directory as it
was. A missing `signify(1)` gives an error that names the command.

### The maintenance command

`scripts/deps --update-sums` tries the alias candidates over the network, and it
writes the entries into `deps/SHA256.txt`. The operator runs it. The install
path never runs it.

The table order is the preference order. The command records the first candidate
that answers, and it reports each other candidate that also answers, so the
operator sees a name that the install path rejects as ambiguous.

The command records the digest of the bytes that one download returned. That
step trusts the first download. The operator compares the new entries against
the upstream checksum file of the release, before the commit.

### One install path for gitleaks

MK-GITLEAKS-4 changes. The manifest provides gitleaks in the `tool` environment,
and CI installs it with `make deps`. A check job that runs the setup-perl action
already runs `make deps-test`, which chains over `deps`. A check job without
that action adds one step that runs `make deps`.

`org/sync/t/ci/workflows.t` therefore permits a `make deps` step in a check
workflow that uses no setup-perl action. It keeps the rule for a workflow that
uses the action, because there the action owns the whole install.

## Work

- `org/sync/scripts/ftp`: add `-f` to the Darwin curl branch.
- `org/sync/scripts/deps`: add the `tool` word, the rejection of an unknown
  environment word, the alias table, the digest tier, the signify tier, the
  temporary-directory download, and `--update-sums`.
- `org/sync/mk/org.mk`: run `tool` before `runtime` in the `deps` target.
- `org/sync/deps/KEYS.txt`: add the file, with the marker and no key line.
- `org/sync/t/ci/workflows.t`: permit a `make deps` step in a check workflow
  without the setup-perl action.
- `spec/make.md` and `spec/sync.md`: add the four units, and amend MK-VERBS-4,
  MK-GITLEAKS-4 and SYNC-BOOTSTRAP-1.
- `spec/STATUS.md`: set each register row.
- `perl/t/deps.t`: cover the alias table, both key forms, both tiers and each
  error path, with a stub `ftp` sibling.
- `deps/Linux.txt` and `deps/SHA256.txt`: add gitleaks in the `tool`
  environment, with the digest that the action holds today.
- `.github/workflows/check.yml`: the `gitleaks` job runs `make deps`.
- Delete this plan.

## Status

### What lands now

Every item of the Work section lands now. The change stays inside this
repository, and each consumer takes it through sync afterwards.

### What waits

The release signature waits. The design signs a `SHA256` manifest of each Perl
release with the organization release key, in
`.github/workflows/perl-release.yml`. That key does not exist yet, and the
Website repository generates the first pair. A signing step without its secret
fails every Perl release, so the step lands with the first key, not here.

The `setup-gitleaks` action waits on each consumer. A consumer that still uses a
deleted action fails at the step, so the action, its test, and WFL-GITLEAKS-1
stay until each check workflow drops the step.

### Open questions

1. The signify tier has no key until the Website repository publishes one. Each
   `dist` entry of a consumer therefore fails at `make deps` after the consumer
   moves it to that tier. The operator confirms that the consumers keep their
   `dist` entries on the digest tier until the first key publishes.
2. Sync gives a `deps/KEYS.txt` to a consumer that holds no deps manifest. The
   operator confirms that the empty directory is acceptable.
