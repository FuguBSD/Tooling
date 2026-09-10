# 009 — Extra release assets in the shared Perl release workflow

## Status

Proposed. It can land now, and it depends on no other plan. FuguBench
DIST-ASSETS-1 waits on it. That release must publish a packed file and an
install script beside the tarballs. The shared workflow publishes the two
tarballs and the signed manifest only.

Extends: WFL-SIGN. The implementation adds one rule for the extra assets in the
manifest, and it lands the rule with the code.

Extends: WFL-REUSE. The implementation adds one rule for the `assets` input, and
it lands the rule with the code.

## Purpose

`perl-release.yml` builds one tarball, copies it to the stable name, signs a
manifest over the two names, and attaches four files. A distribution that ships
one more artifact has no way to name it. FuguBench builds a packed program and
an install script in `make dist`. Both must reach the release with a digest in
the signed manifest. This plan gives the workflow one input for that, and it
changes nothing for a caller that omits it.

## Scope

In scope:

- The `assets` input of `perl-release.yml`, its guard, its manifest lines, and
  its attachment.
- The guards in `perl/t/perl-release.t`.
- The two rules, in `spec/workflows.md`.

Out of scope:

- The build of an extra asset. `make dist` of the caller writes it under
  `build/`, and the workflow reads it there.
- The release body. The `install-note` input serves a caller that wants a line
  about an asset.

## Constraints that shape the design

**One list, one shape.** The input is a whitespace-separated list of file names,
the shape that the `files` input of the `gh-release` action takes. Each name is
a file under `build/` after `make dist`, and never a path. WFL-SIGN-3 holds the
manifest to a file name, and the release directory holds unique names.

**The guard runs before the key.** The name guard of WFL-SIGN-10 covers the
distribution name today. The same guard must cover each asset name: whitespace
cannot occur inside one name, and a parenthesis must not. An absent file is an
error of the build, and the workflow must stop on it before the signing step
reads a secret.

**Each value reaches the shell through the environment.** WFL-SIGN-5 holds. The
input reaches the guard step and the signing step as `DIST_ASSETS`, with the
`DIST_` prefix that WFL-ACTIONS-9 asks of a shared workflow. The test
`perl/t/workflow-env.t` reads every exported name, so the prefix keeps that test
green.

**A release with no key still releases.** WFL-SIGN-7 holds. Without a slot, the
workflow attaches the extra assets with no manifest, as it attaches the
tarballs.

**The default changes nothing.** The input defaults to the empty string. The
four callers of today name no asset, and their releases keep every byte of their
manifests.

## The interface contract

The `workflow_call` inputs gain `assets`: an optional string, default empty, a
whitespace-separated list of file names under `build/`.

A step "Check the release assets" runs after the build step. It reads
`DIST_ASSETS`, and for each name it holds the name to the guard of WFL-SIGN-10
and holds `build/<name>` to an existing regular file. It writes the full
attachment list to a step output: the two tarballs, then each asset.

The signing step adds one `SHA256 (<name>) = <digest>` line for each asset,
inside the loop that names the two tarballs, before the sort.

The release step attaches the list of the check step, and the manifest pair when
the signing step signed.

The new rules read as follows. A plan names no rule number, because a number
exists after the rule lands.

- The rule of WFL-SIGN: "The manifest must name each extra asset that the caller
  names in the `assets` input, beside the two tarballs. The name guard of
  WFL-SIGN-10 covers each asset name."
- The rule of WFL-REUSE: "The Perl release workflow must accept an `assets`
  input: a whitespace-separated list of file names under `build/`. `make dist`
  of the caller writes each file, and the workflow attaches each one. The
  default is empty."

## Files

| File                                 | Change                                        |
| ------------------------------------ | --------------------------------------------- |
| `.github/workflows/perl-release.yml` | The input, the check step, the loop, the list |
| `perl/t/perl-release.t`              | The guards below                              |
| `spec/workflows.md`                  | One rule in WFL-SIGN, and one in WFL-REUSE    |
| `spec/STATUS.md`                     | The two notes name the new guards             |

## Tests

`perl/t/perl-release.t` reads the workflow as text, one step at a time. It
gains:

- The `assets` input exists, it is optional, and its default is empty.
- The check step reads `DIST_ASSETS` from `env:`, and it names no secret.
- The check step refuses a name with whitespace or a parenthesis, in the `case`
  shape of the name guard. It refuses an absent file.
- The signing loop names `DIST_ASSETS` beside the two tarball names, so each
  asset gets a manifest line before the sort.
- The release step attaches the output of the check step, and the manifest pair
  stays behind the `signed` condition.
- `perl/t/workflow-env.t` passes with the new `env:` names. The names carry the
  `DIST_` prefix.

## Acceptance

- `make check` passes.
- A run of the workflow with no `assets` input gives the manifest of today, line
  for line. The guard on the loop text proves it, because the loop adds a line
  for a named asset only.
- WFL-SIGN and WFL-REUSE stay `done`, and each register note names the new
  guards.
- The change deletes this plan.

## Open questions

None. FuguBench DIST-ASSETS-1 names the six assets of its release, and this
input carries the two that the tarball build does not make.
