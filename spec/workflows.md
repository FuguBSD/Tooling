# Actions and reusable workflows

This document specifies the CI building blocks that every FuguBSD repository
shares: the action policy, the reusable workflows, and the setup-perl cache.

<a id="wfl-actions"></a>

## Action policy

- **WFL-ACTIONS-1** — A workflow must use only these actions: GitHub's own
  `actions/`, the actions of this repository, and local paths.
- **WFL-ACTIONS-2** — The synced test `t/ci/workflows.t` must enforce
  WFL-ACTIONS-1 in every consumer.

<a id="wfl-reuse"></a>

## Reusable workflows

- **WFL-REUSE-1** — A reusable workflow must live flat in `.github/workflows/`
  with a language prefix, for example `perl-build.yml`.
- **WFL-REUSE-2** — Inside a reusable workflow, an action reference must use the
  full `FuguBSD/Tooling/...@main` path, never `./`. The workspace holds the
  caller's checkout.
- **WFL-REUSE-3** — `environment: release` must stay in the callee job, and
  `permissions` and `secrets: inherit` must stay in the caller.

<a id="wfl-cache"></a>

## The setup-perl cache

- **WFL-CACHE-1** — The setup-perl cache key must hash `deps/Linux.txt`,
  `scripts/deps`, and `org/sync/scripts/deps`, and nothing else.
- **WFL-CACHE-2** — The test `perl/t/setup-perl.t` must stay in sync with the
  cache key.
