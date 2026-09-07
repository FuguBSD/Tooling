# 004 — The signature of a Perl release

## Status

Proposed.

## Purpose

`scripts/deps` verifies each download in two tiers. The digest tier reads a
recorded sha256. The signify tier reads a signed manifest that the upstream
publishes beside the download.

No Perl release of the organization publishes a manifest, so the signify tier
serves nothing. This plan adds the signature to the shared release workflow.

## Why this blocks the organization

FuguTTX, FuguVM and FuguWeb each hold one `dist` entry on a stable URL:

    runtime dist https://github.com/FuguBSD/Fugu/releases/latest/download/Fugu.tar.gz

A stable URL takes no useful digest, so the entry needs the signify tier. The
install path then derives the manifest from the directory of the URL:

```
deps: the signify tier needs <base>/SHA256, and the server does not answer it
```

Measured on 2026-09-07: that URL answers 404. The three consumers therefore
cannot sync the org pack, whatever `deps/KEYS.txt` declares. They need a Fugu
release that publishes a signed manifest, and this plan is what publishes one.

## Evidence

### One workflow serves every distribution

`.github/workflows/perl-release.yml` builds and publishes every Perl
distribution of the organization: Fugu, FuguVM, FuguWeb and FuguTTX. It already
copies the versioned tarball to a stable name, and a comment names the deps
manifests as the consumer of that name. One change there reaches all four.

The job already binds `environment: release`, which holds the PAUSE secrets, so
a release secret has a home.

### The manifest keys on the file name

`scripts/deps` reads the signed manifest with the file name as the key (Tooling
SYNC-DOWNLOAD-6). One release directory holds unique names, so that key is
unambiguous. The release publishes two names, the versioned tarball and the
stable one, and a consumer can name either. The manifest must therefore hold
both.

### The runner has the command

The runner is Ubuntu, and `signify-openbsd` is an apt package. The workflow
needs no other tool: `sha256sum` and `signify` write the whole pair.

### The key lives in two slots

FuguBSD/Website generates each release key and rotates it. Two organization
secrets hold the private keys, and one organization variable names the active
slot:

| Name                    | Kind     | Value                 |
| ----------------------- | -------- | --------------------- |
| `SIGNIFY_RELEASE_KEY_A` | secret   | a signify private key |
| `SIGNIFY_RELEASE_KEY_B` | secret   | the other slot        |
| `SIGNIFY_RELEASE_SLOT`  | variable | `A` or `B`            |

A step that named one fixed secret could not rotate without a human. The
workflow therefore reads the variable, and then the secret of that slot.

## Design

### The signing step

The workflow installs `signify-openbsd`, writes `SHA256` over both tarballs,
signs it, and attaches both files to the release beside the tarballs.

The published directory then holds four names:

    Fugu-0.3.0.tar.gz
    Fugu.tar.gz
    SHA256
    SHA256.sig

### A release with no key still releases

No key exists today, and FuguWeb must release before one does. The signing step
therefore runs only when the organization holds a key: the variable names a
slot, and the secret of that slot is not empty. Without one the step reports
that it signed nothing, and the release continues.

That rule makes this change safe to land at any time, and it makes the first
signed release the first one after the key publishes.

### The secret reaches the step through the environment

A secret that reached a step through the script text would become part of a
command. Each value goes through `env:` instead, and the private key lands in a
file that the step removes.

## The unit

The implementation adds `WFL-SIGN` to `spec/workflows.md`, and it sets the
register row. The unit states the two published files, the key that signs them,
the slot indirection, and the rule that a release with no key still releases.

## Work

1. `.github/workflows/perl-release.yml`: the signing steps and the two release
   files.
2. `spec/workflows.md` and `spec/STATUS.md`: the `WFL-SIGN` unit and its row.
3. `perl/t/perl-release.t`: the guards that only a text read can hold.
4. Delete `plans/004-release-signature/`.

## Status

### What lands now

Every step above. The signing step is inert until the organization holds a key,
so nothing waits on FuguBSD/Website.

### What waits

- The first signed release. Fugu must release again after the key publishes,
  because the stable URL serves the assets of the latest release.
- The pack sync of FuguTTX, FuguVM and FuguWeb. Each one needs that release.

### What this plan does not resolve

A signature over a stable name binds no version. A server that answers the URL
can replay an earlier signed release. A consumer that must not take an earlier
release names a versioned URL and a recorded digest. Tooling SYNC-DOWNLOAD
records this limit, and this plan does not change it.

Decision 6 of the deps verification work puts the private key in CI. The
signature proves that the asset store holds the bytes that CI built. It does not
prove that CI is honest.
