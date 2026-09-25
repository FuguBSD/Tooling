# 013 — The Homebrew tap takes each release

## Status

This plan describes work of three repositories: Repositories, the new
`FuguBSD/homebrew-tap`, and this one. The Location rule of `plans/CLAUDE.md`
gives a plan one repository. The operator explicitly approved one plan for this
change on 2026-09-25, as for plan 012. The override applies to this plan alone,
and each work package below names the repository that implements it. A review
must not return the Location rule as a finding. The design of the release side
lives here, in WFL-BREW. The design of the tap lives in the tap, in its own
specification.

Work package 1 lands in Repositories, and it can start now. Work package 2 lands
in the tap, and it waits on work package 1. Work package 3 lands in
Repositories, and it waits on the first push of work package 2. Work package 4
lands here, and it waits on work package 3. A release before work package 4
changes no formula.

- Implements: WFL-BREW. The implementation adds the `brew-bump` action, the last
  step of `perl-release.yml`, and the tests of both.

## Purpose

Five repositories release a Perl distribution: Fugu, FuguVM, FuguWeb, FuguBench
and FuguSeed. A user on macOS installs one with `cpanm` today, and then updates
it by hand. A Homebrew tap gives `brew install fugubsd/tap/fugu`, and
`brew upgrade` carries each update. The tap holds one formula per repository,
and the release workflow keeps each formula current. No hand touches a formula
after a release.

## Scope

In scope:

- The repository block, the deploy key and the `release` environment secret in
  Repositories.
- The first content of the tap: five formulae, the org pack, the brew gate and
  the check workflow.
- The `brew-bump` action, the last step of `perl-release.yml`, the tests, and
  the unit WFL-BREW.

Out of scope:

- The install documentation of each project. `INSTALL.md` and the web page of a
  project name `cpanm` today, and a change of each one is a change of that
  project.
- A bottle. The tap installs from source, and a binary package needs a build
  matrix that no present need asks for.
- A signature check inside the tap. Homebrew verifies the digest, and the digest
  comes from the tarball that the release job built. The `SHA256.sig` manifest
  of WFL-SIGN serves the FuguBench tier, and the tap does not read it.
- A Linux run of the brew gate. The tap serves macOS, and one runner is enough.

## Constraints that shape the design

**One credential, one direction.** A release job holds `github.token`, and that
token reaches the repository of the caller alone. A push to the tap needs a
second credential. The releng GitHub App can mint an org-wide token. Its private
key lives in one environment of Website, and Repositories SET-RELENG-4 keeps it
there. A deploy key of the tap is repo-level, so OpenTofu manages it end to end
under Repositories SET-AUTH-2. It never expires, and it can push and nothing
else. A fine-grained token can also dispatch a workflow, but it expires inside a
year, and the org policy on such tokens is unknown.

**No third-party action.** D-04 and WFL-ACTIONS-1 allow GitHub's own actions,
the actions of this repository, and local paths. The bump is therefore an action
of this repository, and its logic is one Perl script with core modules alone.
`actions/checkout` takes an `ssh-key` input, and it configures the key for the
later `git push` of the same checkout.

**No project fact in a shared file.** D-02 and D-14 keep the formula name out of
the workflow text. The formula name is the repository name in lower case, so the
action derives it from `github.repository`, and no caller gains an input. The
distribution name comes from the `dist` input that every caller sets today.

**The version lives in the file name.** The release publishes
`<dist>-<version>.tar.gz` beside `<dist>.tar.gz`. Homebrew reads the version
from the stem of the versioned name, so a formula carries no `version` line. The
bump changes the `url` line and the `sha256` line alone.

**The bump is unconditional.** Every caller of `perl-release.yml` is a release
repository, and every release repository holds a formula. A `brew` input would
take the same value in every caller. A tap without the formula fails the step,
and the failure names the path.

**A rerun is a hand repair.** The step runs last, so a failure leaves the GitHub
release and the PAUSE upload complete. A rerun of the job fails on
`gh release create`, because the release exists. The action prints the formula
path, the URL and the digest on failure, and the operator writes the two lines
by hand. Two releases at one time race on the push, and the second one fails on
a non-fast-forward. No retry logic lands, because no present need asks for it.

**The tap tests itself.** A push of a deploy key raises a push event, so the
check workflow of the tap runs after each bump. The check installs each formula
from source, runs its test block, and audits it. A broken formula turns `main`
of the tap red, and the failure names the formula.

## The interface contract

The action `actions/brew-bump/action.yml` is composite. Its inputs are:

| Input        | Meaning                                                |
| ------------ | ------------------------------------------------------ |
| `key`        | The private deploy key of the tap                      |
| `repository` | The repository of the caller, `github.repository`      |
| `url`        | The URL of the versioned tarball of the GitHub release |
| `file`       | The path of the built tarball, under `build/`          |
| `tag`        | The release tag, for the commit subject                |

The action checks out `FuguBSD/homebrew-tap` into `tap/` with
`actions/checkout`, and the `ssh-key` input of the checkout reads `key`. One
script step does the rest. Its `env:` block binds `repository`, `url`, `file`
and `tag` to `BUMP_REPOSITORY`, `BUMP_URL`, `BUMP_FILE` and `BUMP_TAG`, per
WFL-BREW-6. A `with:` expression cannot lower-case, so the step derives the
formula name in shell. It takes the part of `BUMP_REPOSITORY` after the slash,
in lower case, with `tr`. It computes the SHA-256 digest of `file`, and it runs
`bump` on `tap/Formula/<name>.rb` with the URL and the digest. It then commits
as `github-actions[bot]` with the subject `feat(<name>): <tag>`, and pushes
`main`.

The script `actions/brew-bump/bump` takes three arguments: the formula path, the
URL and the digest. It replaces the value of the `url` line and of the `sha256`
line, and it writes the file only when it replaced both. It prints nothing on
success. On failure it prints the three arguments and the absent line to
standard error, and it exits 1. It is Perl v5.34 with core modules alone, as
SYNC-BOOTSTRAP-1 asks of a synced script.

The last step of `perl-release.yml` calls
`FuguBSD/Tooling/actions/brew-bump@main` with these `with:` inputs, as the
`gh-release` step does:

- `key`: `${{ secrets.HOMEBREW_TAP_KEY }}`, from the `release` environment.
- `repository`: `${{ github.repository }}`.
- `url`:
  `https://github.com/<repository>/releases/download/<tag>/<dist>-<version>.tar.gz`.
- `file`: `build/<dist>-<version>.tar.gz`, the tarball of the build step.
- `tag`: the tag of the version step.

The tap holds:

- `Formula/fugu.rb`, `Formula/fuguvm.rb`, `Formula/fuguweb.rb`,
  `Formula/fugubench.rb` and `Formula/fuguseed.rb`. Each `url` names the
  versioned tarball of the current release. Each formula names its perl and each
  CPAN prerequisite of the distribution as a `resource`. The four `App-`
  formulae depend on `fugubsd/tap/fugu`. Each `test do` block runs the
  executable of the distribution, or loads the module of Fugu.
- The org pack, with `.toolingrc` and no `sync.pack` line.
- `mk/local.mk`, which adds a `brew-check` target to the check gates. The target
  installs each formula from source, runs `brew test`, and runs
  `brew audit --strict`.
- `.github/workflows/check.yml`, which runs `make check` on `macos-latest` and
  the drift job of every consumer.
- `spec/`, with one document `tap.md`. Its units hold the formula shape and the
  gate above, and the tap owns their text.

## Work packages

### WP1 — Repositories creates the tap and the credential

In Repositories, per SET-IMPORT-1:

1. Add `github_repository.homebrew_tap` to `tofu/repositories.tf`, with the name
   `homebrew-tap`, public, and the same flags as the other blocks. Homebrew
   resolves `brew tap fugubsd/tap` to this name, so the name has no `Fugu`
   prefix.
2. Generate an ed25519 key pair with `ssh-keygen`, with no passphrase. Put the
   public key in `tofu/repositories.tf` as `github_repository_deploy_key`
   `.homebrew_tap`, with `read_only = false`. Put the private key in
   `secrets.auto.tfvars` as `homebrew_tap_key`, and add the variable to
   `variables.tf` and to the example file.
3. Add `github_actions_environment_secret.homebrew_tap_key` to
   `tofu/environments.tf`, over the `release` environments, with the name
   `HOMEBREW_TAP_KEY`.
4. Apply from the main checkout, and close with `tofu plan -detailed-exitcode`.

The tap joins no list in this package. The default-branch resource needs a
branch, and the repository is empty.

### WP2 — The tap gets its first content

In the tap, as one first push to `main`:

1. Sync the org pack with `.toolingrc`. Write the `README.md` in the shared
   shape: the title, two paragraphs, and the Commands section.
2. Write the five formulae. Take the URL and the digest of the current release
   of each repository from its `SHA256` asset.
3. Write `mk/local.mk` with the `brew-check` gate, and `check.yml`.
4. Write `spec/` with `tap.md`, `index.md`, `DECISIONS.md` and `STATUS.md`.
5. Run `make check </dev/null` on macOS. The gate installs each formula from
   source, so it proves each `resource` list.

The formula of FuguBench comes from its CPAN release, because no checkout of it
sits in the workspace.

### WP3 — Repositories adopts the branch

In Repositories, per SET-IMPORT-2: add `homebrew-tap` to `all_repos` and to
`fugu_repos`, apply, and close with `tofu plan -detailed-exitcode`. The tap
releases no Perl distribution, so it joins neither `release_repos` nor the
selected-repository list of any releng secret.

### WP4 — Tooling bumps the formula on each release

Here:

1. Add `actions/brew-bump/action.yml` and `actions/brew-bump/bump`, per the
   interface contract. The `env:` block of the script step binds the `BUMP_*`
   variables.
2. Add the last step to `perl-release.yml`, after the PAUSE step, with the
   `with:` inputs of the contract.
3. Add `perl/t/brew-bump.t` and `perl/t/brew-bump-action.t`, and extend
   `perl/t/perl-release.t`.
4. Set WFL-BREW to `done` in `spec/STATUS.md`, and delete this plan.

The change is minor-level, so it merges through `pull-it` and the review panel.
The first release after the merge proves the step end to end. Dispatch a patch
release of FuguSeed for it, because its formula is the smallest.

## Tests

`perl/t/brew-bump.t` runs the script against a fixture formula in a temporary
directory, with no network:

- Both lines change, and every other byte stays.
- An absent formula, an absent `url` line, and an absent `sha256` line each exit
  1, and the message names the path.
- A success prints nothing.

`perl/t/brew-bump-action.t` reads `actions/brew-bump/action.yml` as text, as
`perl/t/setup-perl.t` reads the `setup-perl` action, and guards:

- The checkout step names `FuguBSD/homebrew-tap`, and its `ssh-key` input reads
  `inputs.key`.
- The `env:` block of the script step binds `repository`, `url`, `file` and
  `tag` to `BUMP_REPOSITORY`, `BUMP_URL`, `BUMP_FILE` and `BUMP_TAG`.
- The script derives the formula name with `tr`, and the formula path is
  `Formula/<name>.rb`.
- The commit subject is `feat(<name>): <tag>`.
- The push goes to `main`.

`perl/t/perl-release.t` gains one subtest:

- The step exists, and it is the last step of the job.
- The step uses `FuguBSD/Tooling/actions/brew-bump@main`.
- The key input reads `secrets.HOMEBREW_TAP_KEY`.
- The URL input names the versioned tarball.

Prove each new assertion with the mutation it targets before the panel sees it.

## Rollback

Remove the last step of `perl-release.yml`. The tap keeps its formulae, and a
hand edit of two lines carries a release. Remove the deploy key and the secret
from OpenTofu, and apply.

## Open questions

- The perl of a formula. `depends_on "perl"` builds the Homebrew perl once, and
  `uses_from_macos "perl"` takes the system perl, which is 5.34 on macOS 13 and
  later. The floor of the distributions is 5.34. The tap decides in WP2, and the
  brew gate proves the choice.
- The runtime programs of FuguWeb. `fuguweb` runs `mandoc` and `lowdown`, and
  both live in homebrew-core. The formula names each one under `depends_on`.
