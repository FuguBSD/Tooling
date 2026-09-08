# Actions and reusable workflows

This document specifies the CI building blocks that every FuguBSD repository
shares. It covers the action policy, the reusable workflows, the web publish
workflow, the setup-perl cache, the setup-uv cache, and the gitleaks gate.

<a id="wfl-actions"></a>

## Action policy

- **WFL-ACTIONS-1** — A workflow must use only these actions: GitHub's own
  `actions/`, the actions of this repository, and local paths.
- **WFL-ACTIONS-2** — The synced test `t/ci/workflows.t` must enforce
  WFL-ACTIONS-1 in every consumer.
- **WFL-ACTIONS-3** — A workflow step must run `make deps` with no argument. A
  word after it names a second target, and `make` stops. The synced test must
  refuse such a step, because the fault reaches the runner alone. `deps-test`
  and `deps-develop` are targets of their own, and the test must accept each
  one.
- **WFL-ACTIONS-10** — No consumer can guard the synced test, so this repository
  must guard it. The test `perl/t/sync-workflows.t` must drive the synced test
  against fixture trees, and must hold it to WFL-ACTIONS-3 in both directions.
- **WFL-ACTIONS-4** — A workflow and an action must not export a name that a
  make fragment leaves open to the environment. `make` imports the environment.
  A fragment that assigns a name with `?=` keeps the imported value, and one
  that assigns it with `+=` appends to it. A fragment that reads a name and
  assigns it at no point takes the whole value from the environment. `make`
  holds `MAKEFLAGS`, `GNUMAKEFLAGS`, `MAKEFILES` and `MAKELEVEL` itself. Each
  such name is open. A plain `=` replaces the imported value, and that name is
  free. MK-SUBSET-1 gives a fragment `=`, `?=` and `+=` alone.
- **WFL-ACTIONS-5** — A name that one fragment leaves open must stay open, also
  when another fragment controls it. A consumer holds its own `mk/local.mk`, and
  a shared workflow runs in the tree of the consumer.
- **WFL-ACTIONS-6** — The ban of WFL-ACTIONS-4 must hold for every step. A step
  that runs no `make` today can run one tomorrow, and an export at job level
  reaches every step of the job. An `env:` block exports a name, and a write to
  `$GITHUB_ENV` exports one too.
- **WFL-ACTIONS-7** — The test `perl/t/workflow-env.t` must enforce
  WFL-ACTIONS-4 over the workflows and the actions of this repository.
- **WFL-ACTIONS-8** — The synced test `t/ci/workflows.t` must enforce
  WFL-ACTIONS-4 in each consumer. It must check the workflows and the actions of
  that consumer against the fragments of that consumer.
- **WFL-ACTIONS-9** — A shared workflow and a shared action run in the tree of
  the consumer, and they read the fragments of the consumer. No test of this
  repository holds them to the `mk/local.mk` of a consumer, and no test of a
  consumer holds them either. A shared workflow must therefore export a name
  that carries the scope of the workflow, as `DIST_NAME` does.

<a id="wfl-reuse"></a>

## Reusable workflows

- **WFL-REUSE-1** — A reusable workflow must live flat in `.github/workflows/`
  with a scope prefix: the language or the area, for example `perl-build.yml`
  and `web-publish.yml`.
- **WFL-REUSE-2** — Inside a reusable workflow, an action reference must use the
  full `FuguBSD/Tooling/...@main` path, never `./`. The workspace holds the
  caller's checkout.
- **WFL-REUSE-4** — The Perl release workflow must accept the release tag as an
  input. An environment that cannot push a tag makes the tag inside a workflow.
  GitHub raises no push event for a tag that `GITHUB_TOKEN` pushes. The input
  must select both the checkout and the version. Without it the workflow must
  read the ref of the push.
- **WFL-REUSE-3** — `environment: release` must stay in the callee job, and
  `permissions` and `secrets: inherit` must stay in the caller.

<a id="wfl-sign"></a>

## The release signature

`scripts/deps` verifies a download in two tiers, and the signify tier reads a
manifest that the upstream publishes beside the download. The Perl release
workflow publishes that manifest, so one change serves every distribution of the
organization.

- **WFL-SIGN-1** — The Perl release workflow must publish a `SHA256` file and a
  `SHA256.sig` file beside the release tarballs.
- **WFL-SIGN-2** — The manifest must name the versioned tarball and the stable
  tarball. A consumer can name either one, and SYNC-DOWNLOAD-6 keys the manifest
  on the file name.
- **WFL-SIGN-3** — The manifest must hold a file name and never a path. One
  release directory holds unique names.
- **WFL-SIGN-4** — Two organization secrets must hold the release keys under
  fixed names. One organization variable must name the active slot. A step that
  names one fixed secret cannot rotate without a human.
- **WFL-SIGN-5** — Each secret and each caller input must reach the signing step
  through the environment. A value in the script text becomes part of a command.
- **WFL-SIGN-6** — The private key must land in a file with no group mode and no
  other mode. The step must remove that file, whatever the outcome of the run.
- **WFL-SIGN-7** — A release must succeed when the organization names no slot.
  The step must report that it signed nothing, and it must attach no manifest.
- **WFL-SIGN-8** — The key file must end in a newline. `signify(1)` refuses a
  key file without one.
- **WFL-SIGN-9** — A named slot that holds no key must fail the release. That is
  a release that was meant to carry a signature.
- **WFL-SIGN-10** — The workflow must refuse a distribution name that holds
  whitespace or a parenthesis. The manifest reader of a consumer takes neither.
- **WFL-SIGN-11** — The package install must run in its own step, before a
  secret reaches the environment of any step.

<a id="wfl-web"></a>

## The web publish workflow

- **WFL-WEB-1** — The reusable workflow `web-publish.yml` must build the FuguWeb
  site of the caller with `fuguweb build`, and must deploy the result to GitHub
  Pages.
- **WFL-WEB-2** — The workflow must install `fuguweb` from the release tarballs
  of Fugu and FuguWeb, never from a checkout.
- **WFL-WEB-3** — The workflow must run `fuguweb check` on the build before the
  deploy, and a check failure must stop the deploy.
- **WFL-WEB-4** — The `github-pages` environment must stay in the callee job,
  and `permissions` and the concurrency group must stay in the caller.

<a id="wfl-cache"></a>

## The setup-perl cache

- **WFL-CACHE-1** — The setup-perl cache key must hash `deps/Linux.txt`,
  `scripts/deps`, and `org/sync/scripts/deps`, and nothing else.
- **WFL-CACHE-2** — The test `perl/t/setup-perl.t` must stay in sync with the
  cache key.

<a id="wfl-uv"></a>

## The setup-uv cache

- **WFL-UV-1** — The setup-uv action must install a pinned uv release from its
  tarball. It must run `uv sync --locked` on a cache hit and on a miss. The sync
  must fail on a stale lockfile, and must not rewrite it: a repair here would
  blind every lockfile gate after the action.
- **WFL-UV-2** — The setup-uv cache key must hash `uv.lock`, `.python-version`,
  and `pyproject.toml`, and nothing else. The key must also name the repository,
  the uv release, and the machine architecture, because the environment holds
  platform wheels.
- **WFL-UV-3** — The test `perl/t/setup-uv.t` must stay in sync with the cache
  key.

<a id="wfl-gitleaks"></a>

## The gitleaks gate

- **WFL-GITLEAKS-2** — The check workflow of a repository must run the gitleaks
  gate in a job with a `fetch-depth: 0` checkout. The job runs `make gitleaks`,
  or `make check` per MK-VERBS-3. A shallow checkout hides old commits from the
  scan.
- **WFL-GITLEAKS-3** — The synced test `t/ci/workflows.t` must enforce
  WFL-GITLEAKS-2 in every consumer with a check workflow.
- **WFL-GITLEAKS-4** — A repository must install gitleaks from its deps
  manifest, per MK-GITLEAKS-4. No action must install it. One pin in one
  manifest serves the operator gate and the CI gate.
