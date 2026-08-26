# Actions and reusable workflows

This document specifies the CI building blocks that every FuguBSD repository
shares. It covers the action policy, the reusable workflows, the web publish
workflow, the setup-perl cache, and the setup-uv cache.

<a id="wfl-actions"></a>

## Action policy

- **WFL-ACTIONS-1** — A workflow must use only these actions: GitHub's own
  `actions/`, the actions of this repository, and local paths.
- **WFL-ACTIONS-2** — The synced test `t/ci/workflows.t` must enforce
  WFL-ACTIONS-1 in every consumer.

<a id="wfl-reuse"></a>

## Reusable workflows

- **WFL-REUSE-1** — A reusable workflow must live flat in `.github/workflows/`
  with a scope prefix: the language or the area, for example `perl-build.yml`
  and `web-publish.yml`.
- **WFL-REUSE-2** — Inside a reusable workflow, an action reference must use the
  full `FuguBSD/Tooling/...@main` path, never `./`. The workspace holds the
  caller's checkout.
- **WFL-REUSE-3** — `environment: release` must stay in the callee job, and
  `permissions` and `secrets: inherit` must stay in the caller.

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
  tarball, and must run `uv sync --locked` on a cache hit and on a miss. The
  sync must fail on a stale lockfile, and must not rewrite it: a repair here
  would blind every lockfile gate after the action.
- **WFL-UV-2** — The setup-uv cache key must hash `uv.lock`, `.python-version`,
  and `pyproject.toml`, and nothing else. The key must also name the repository,
  the uv release, and the machine architecture, because the environment holds
  platform wheels.
- **WFL-UV-3** — The test `perl/t/setup-uv.t` must stay in sync with the cache
  key.
