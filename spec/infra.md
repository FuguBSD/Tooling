# The shared infrastructure design

The FuguBSD projects run their compute on one Scaleway Organization, with one
Scaleway Project for each project. This document specifies the shared design. It
covers the layout, the state store, the credentials, the spend guardrails, the
teardown, the task runner, and the CI shape.

No code of this repository implements a unit of this document. The `infra` pack
of [sync.md](sync.md#sync-packs) delivers the rules of the design to a consumer,
at `infra/CLAUDE.md`, and the consumer OpenTofu code implements them. `<code>`
is the project short code that the consumer specification states.

A project fact stays out of this document. A resource, a budget value, a bucket
suffix, and a documented exception each live in the consumer specification or
the consumer runbook.

<a id="infra-layout"></a>

## Layout

Each stack holds the resources of one lifetime:

```
infra/
├── modules/
├── persistent/
├── dev/
├── train/
└── image/
```

- **INFRA-LAYOUT-1** — `infra/persistent` must hold each resource that outlives
  a campaign.
- **INFRA-LAYOUT-2** — `infra/dev` must hold the development host, and
  `infra/train` must hold one compute instance. A session brings each one up and
  down.
- **INFRA-LAYOUT-3** — `infra/image` must hold the OpenBSD guest image. An apply
  of the stack happens on an OpenBSD release.
- **INFRA-LAYOUT-4** — `infra/modules` must hold each shared module of the
  consumer.

<a id="infra-state"></a>

## The state store

The state records a secret in clear text, so one control alone does not hold it.
The encryption keeps the object unreadable. The bucket policy keeps the object
unreachable, and the key rule keeps a machine key out of it.

- **INFRA-STATE-1** — The state bucket must keep versioning on, and a lifecycle
  rule must expire a noncurrent version after 30 days.
- **INFRA-STATE-2** — A bucket policy is an allow list, and a new policy
  replaces the old one. A policy change must run against a scratch bucket first.
- **INFRA-STATE-3** — The recovery of a bad state must stay a human act. The
  consumer runbook must hold the `tofu force-unlock` procedure and the
  `tofu import` procedure.

<a id="infra-credentials"></a>

## The credentials

Scaleway offers one machine credential: a stored API key.

- **INFRA-CREDENTIALS-1** — Each stored API key must carry a scope, an expiry,
  and a rotation period.
- **INFRA-CREDENTIALS-2** — Three IAM applications must split the credentials by
  blast radius: pipeline, operator, and train.
- **INFRA-CREDENTIALS-3** — The pipeline policy must permit the apply and the
  destroy of `infra/dev`, `infra/train`, and `infra/image`. It must also permit
  Object Storage in the project, and the read of billing data. It must not hold
  `IAMManager`, `OrganizationManager`, or `ProjectManager`.
- **INFRA-CREDENTIALS-4** — The operator policy must add the IAM administration
  of `infra/persistent`. A human holds the operator key, in a HOME profile of
  its own.
- **INFRA-CREDENTIALS-5** — The train policy must permit Object Storage in the
  project, and nothing else. Each train key lives for one campaign.
- **INFRA-CREDENTIALS-6** — An agent key must live in the HOME profiles of its
  project. Each project needs a `~/.config/scw/config.yaml` profile, and a
  matching `~/.aws/credentials` section. Each one carries the name of its
  Scaleway Project. An agent key must take the smallest scope of the task, and a
  short expiry.
- **INFRA-CREDENTIALS-7** — IAM grants Object Storage for each project, and not
  for each bucket. A bucket policy is the only per-bucket control.
- **INFRA-CREDENTIALS-8** — Object Storage needs up to five minutes for a new
  policy. The first call after a policy change must retry.
- **INFRA-CREDENTIALS-9** — A rotation of the pipeline key must happen after
  each campaign, and at 90 days. The rotation creates a second key on the
  application, and sets it in the CI secret. It then confirms one workflow run,
  and deletes the old key.
- **INFRA-CREDENTIALS-10** — CI must create the train key at
  `make infra-up STACK=train`, with `expires-at` set to the `<code>:expires`
  tag. CI must deliver the key to the instance over SSH after boot, and
  `make infra-down STACK=train` must delete the key. The expiry is the backstop.
- **INFRA-CREDENTIALS-11** — Each SSH key is an IAM resource, and a change to
  `ssh_key_ids` of an Elastic Metal server forces a reinstall. The consumer
  runbook must record which key reaches which host.
- **INFRA-CREDENTIALS-12** — A fourth IAM application must hold the agent keys.
  A human creates it, so the consumer specification must record it as a
  documented exception.

<a id="infra-spend"></a>

## The spend guardrails

Five guardrails hold the spend, and each one covers a different failure:

| Guardrail                         | Kind                  | Effect                                  |
| --------------------------------- | --------------------- | --------------------------------------- |
| Per-Organization quotas           | Platform, hard        | Scaleway refuses to create the resource |
| Scoped IAM policies               | Platform, hard        | Scaleway refuses the action             |
| The monthly budget and its alerts | Platform, soft        | Scaleway sends a notification           |
| The pre-apply forecast check      | Pipeline              | The pipeline stops its own apply        |
| The idle watchdog                 | Pipeline, best effort | The pipeline destroys an idle stack     |

- **INFRA-SPEND-1** — A Scaleway budget notifies, and it does not block. The
  budget must not be the only guardrail of a compute offer.
- **INFRA-SPEND-2** — An alert must fire at 50, 75, and 100 percent of the
  budget, to email and to a CI webhook. Scaleway alerts on the amount after
  discount and tax.
- **INFRA-SPEND-3** — The forecast check must read
  `GET /billing/v2beta1/consumptions`. The forecast is the hourly price
  multiplied by the maximum lifetime of the run.
- **INFRA-SPEND-4** — A train stack is idle when three conditions hold together.
  It holds a server tagged `<code>:lifecycle=ephemeral`. The server is older
  than 20 minutes. The heartbeat object is absent, or older than 20 minutes.
- **INFRA-SPEND-5** — The training driver must write the heartbeat every 60
  seconds. It must claim the stack once at start, with an `If-None-Match: *`
  conditional write.
- **INFRA-SPEND-6** — The watchdog must destroy the train stack when the stack
  is idle, or when the time passes the `<code>:expires` tag.
- **INFRA-SPEND-7** — `make infra-watchdog` must run every 30 minutes from CI,
  and every 30 minutes from a timer on the development host. A scheduled GitHub
  workflow alone is best effort.

<a id="infra-teardown"></a>

## The teardown

`tofu destroy` reads the state, so it alone is not a teardown.

- **INFRA-TEARDOWN-1** — A teardown must find a resource that the state does not
  name. A cancelled apply can create such a resource, and it bills without
  limit.
- **INFRA-TEARDOWN-2** — A destroy set must follow the billing model, and not
  the resource graph. Scaleway bills a reserved IPv4 address, attached or not.
- **INFRA-TEARDOWN-3** — The consumer runbook must record each bucket name of
  the project. A destroy of `infra/persistent` surrenders each name.

<a id="infra-runner"></a>

## The task runner

One target set drives the infrastructure of each consumer:

| Target                           | Effect                                          |
| -------------------------------- | ----------------------------------------------- |
| `make infra-bootstrap`           | The state bucket and its lifecycle rule         |
| `make infra-fmt-check`           | `tofu fmt -recursive -check`                    |
| `make infra-validate STACK=name` | `tofu validate`                                 |
| `make infra-check`               | `infra-fmt-check`, then each `infra-validate`   |
| `make infra-plan STACK=name`     | `tofu plan` — what a session creates            |
| `make infra-plan-ro STACK=name`  | `tofu plan -lock=false` — the pull-request plan |
| `make infra-up STACK=name`       | `tofu apply` — billing starts here              |
| `make infra-down STACK=name`     | `tofu destroy` — billing stops here             |
| `make infra-status`              | List the live resources                         |
| `make infra-price STACK=name`    | Print the hourly price of the stack compute     |
| `make infra-cost`                | Month-to-date consumption against the budget    |
| `make infra-watchdog`            | Destroy an idle train stack; report an orphan   |

- **INFRA-RUNNER-1** — The consumer must define each target of the table in its
  own make fragment. No shared fragment of this repository ships them.
- **INFRA-RUNNER-2** — `make infra-fmt-check` and `make infra-validate` must run
  with no credential.
- **INFRA-RUNNER-3** — `make infra-bootstrap` must stay a human step, and it
  must run once for a project.

<a id="infra-ci"></a>

## The CI shape

| Trigger             | Job                                     | Credential         | Guard                                   |
| ------------------- | --------------------------------------- | ------------------ | --------------------------------------- |
| `pull_request`      | `tofu fmt -check`, `tofu validate`      | none               | Each pull request                       |
| `pull_request`      | `tofu plan -lock=false`                 | none, or read only | The branch is not a fork                |
| `push` to `main`    | `tofu apply` of `dev`, `train`, `image` | pipeline           | Environment `infra-apply`               |
| `workflow_dispatch` | Any action of `dev`, `train`, `image`   | pipeline           | Environment `infra-apply`               |
| `workflow_dispatch` | `tofu apply` of `infra/persistent`      | operator           | Environment `infra-admin`, human review |
| `schedule`          | Watchdog, reinstall                     | pipeline           | Environment `infra-apply`               |

- **INFRA-CI-1** — The CI of the consumer must hold each job of the table. Each
  job must take the credential and the guard of its row.
- **INFRA-CI-2** — A daily export must write the Scaleway Audit Trail of each
  day to a bucket of the consumer. The Audit Trail keeps 90 days of compute
  calls.
