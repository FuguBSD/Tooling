# Shared infrastructure instructions

The `infra` pack of FuguBSD/Tooling owns this file. `scripts/sync` overwrites
it. Edit the canonical copy in FuguBSD/Tooling.

These instructions hold the shared rules for the OpenTofu code under `infra/`:
naming, layout, tags, state, credentials, spend guardrails, and teardown. The
consumer specification states the project resources, the budget, and the
documented exceptions. `<code>` is the project short code, in lower case, for
example `ttx`. The consumer specification states its code.

## Ground rules

- OpenTofu declares each resource. Do not make a resource in the console. The
  consumer specification lists the documented exceptions.
- The infrastructure code has the ISC license.
- The shared platform is Scaleway. A consumer can manage an other platform under
  `infra/`, for example GitHub in the Repositories repository. The Scaleway
  rules of this file apply to each stack that declares a Scaleway resource.
- Prices change. Each recorded price carries the date it was read. Read the live
  price before you create a resource.
- Scaleway documents a minimum of 60 minutes for each created resource, so a
  cycle shorter than one hour saves nothing.

## Naming

The naming rule lives in the Repositories specification (Repositories
SET-NAMING-1).

- Each Scaleway resource name must use the pattern `<project>.<env>.<thing>`,
  for example `ttx.prod.train`.
- Each bucket name must use the pattern `<code>-<purpose>-<suffix>`. A bucket
  name is unique across the whole platform. The bootstrap runbook of the
  consumer records the suffix.

## Region and zone

| Item                    | Value                         |
| ----------------------- | ----------------------------- |
| Region                  | `fr-par`                      |
| Zone                    | `fr-par-2`                    |
| Object Storage endpoint | `https://s3.fr-par.scw.cloud` |

One region and one zone hold everything. A quota applies per Organization and
per Availability Zone, so one zone caps a defective loop. Do not put a bucket in
a second region.

## Version pins

| Tool              | Constraint                       |
| ----------------- | -------------------------------- |
| OpenTofu          | `required_version = ">= 1.11.0"` |
| Scaleway provider | `version = "~> 2.80"`            |

Each stack must hold a `versions.tf` with both constraints, and must commit its
`.terraform.lock.hcl`. A stack must not use `action` resources or list
resources: OpenTofu supports neither.

## Layout

```
infra/
├── modules/              # a module needs three or more callers
├── persistent/           # buckets, IAM, budget, alerts — applied rarely
├── dev/                  # the development host — up/down around each session
├── train/                # one GPU instance — up/down around each session
└── image/                # the OpenBSD guest image — applied on an OpenBSD release
```

The four stack names are fixed. Each stack is a root module and holds
`versions.tf`, `backend.tf`, `providers.tf`, `variables.tf`, `outputs.tf`,
`locals.tf`, and its committed lock file.

- A stack must not read the state of another stack with
  `terraform_remote_state`.
- A stack must not contain a hardcoded Scaleway UUID. Resolve each identifier
  with a data source.
- Create a module only when a pattern has three or more callers.

## Tags

Each stack must tag each resource it creates. An instance takes a list of
strings, and a bucket takes a map. Build both shapes from one map in
`locals.tf`.

| Tag                | Example                               | Purpose                             |
| ------------------ | ------------------------------------- | ----------------------------------- |
| `<code>:stack`     | `<code>:stack=train`                  | Names the owning stack              |
| `<code>:managed`   | `<code>:managed=true`                 | Marks a resource the pipeline owns  |
| `<code>:lifecycle` | `<code>:lifecycle=ephemeral`          | The watchdog reaps `ephemeral` only |
| `<code>:run-id`    | `<code>:run-id=8891fa2c`              | Ties a resource to one CI run       |
| `<code>:expires`   | `<code>:expires=2026-08-02T18:00:00Z` | The hard end of the lease, in UTC   |

An ad-hoc resource — a probe, an experiment — must carry
`<code>:lifecycle=ephemeral` and a near `<code>:expires`. The watchdog is then
the backstop. Delete the resource in the same session.

## Buckets

The consumer specification states the bucket set and the versioning of each
bucket.

- No bucket is public. Each bucket keeps the default private ACL.
- Set `force_destroy = false` on each bucket.
- A lifecycle rule must abort an incomplete multipart upload after one day.
  Scaleway bills an incomplete upload.
- Object lock must stay off. Object lock cannot be disabled again.

## State

State lives in a dedicated Object Storage bucket, through the S3-compatible
backend. Each stack keeps its own key.

- The backend must set `use_lockfile = true`: the bucket holds a native lock.
- `tofu apply` must not set `-lock=false`. A pull-request plan must set it,
  because a plan writes no state.
- Use `endpoints = { s3 = ... }` and `use_path_style`. The arguments `endpoint`
  and `force_path_style` are deprecated.
- The backend takes its credential from the environment. The backend block must
  not hold a key.
- The state bucket has versioning on, and a lifecycle rule expires a noncurrent
  version after 30 days.

The state holds secrets. Three controls apply together:

1. OpenTofu must encrypt the state and the plan.
2. A bucket policy on the state bucket must name each principal that needs the
   bucket, and no other principal.
3. OpenTofu must not create the pipeline key, the operator key, or the train
   key.

A bucket policy is an allow list, and a new policy overwrites the old one: a
principal that the policy does not name loses access. Test each bucket-policy
change on a scratch bucket first. Recovery from a bad state is a human act. The
consumer runbook holds the `tofu force-unlock` and `tofu import` procedures.

## Credentials

A stored API key is the only machine credential, so each key needs a scope, an
expiry, and a rotation period. Three IAM applications split the credentials by
blast radius. The persistent stack declares each application and each policy,
and must not declare an API key.

- **Pipeline.** Its key lives in the CI secrets. Its policy permits: apply and
  destroy of `infra/dev`, `infra/train`, and `infra/image`; Object Storage in
  the project; read of billing data. The policy must not hold `IAMManager`,
  `OrganizationManager`, or `ProjectManager`.
- **Operator.** A human holds its key (`SCW_ACCESS_KEY`, `SCW_SECRET_KEY`,
  `SCW_DEFAULT_PROJECT_ID`, `SCW_DEFAULT_ORGANIZATION_ID`). Its policy adds the
  IAM administration for `infra/persistent`. In CI, only a protected manual
  dispatch uses it.
- **Train.** Its policy permits Object Storage in the project, and nothing else.
  Each of its keys lives for one campaign.
- **Agent.** An agent holds its key in the `.env` of its checkout. The key takes
  the smallest scope that the task needs, and a short expiry.

Each checkout holds its own `.env`, with its own key. Run each command from the
checkout of the target project. A command from an other checkout uses an other
key, and its output can look correct. Treat an authentication failure first as
an expired key.

CI must export exactly one credential set, as environment variables. The
`provider` block must not set `access_key`, `secret_key`, or `project_id`. IAM
grants Object Storage per project, not per bucket: a bucket policy is the only
per-bucket control. A new policy needs up to five minutes for Object Storage, so
the first call after a change must retry.

A rotation is a create and a delete, because an expiry cannot change. Rotate the
pipeline key after each campaign, and at 90 days:

1. Create a second key on the same application.
2. Set the new key in the CI secret.
3. Run one workflow and confirm it passes.
4. Delete the old key.

### The train credential

The train key must not touch OpenTofu, `user_data`, or state: `user_data` is
readable through the instance API, and a managed key writes its secret to state.

1. At `make infra-up STACK=train`, CI creates a key on the train application
   with `scw iam api-key create`, with `expires-at` set to the `<code>:expires`
   tag.
2. CI delivers the key to the instance over SSH, after boot.
3. `make infra-down STACK=train` deletes the key. The expiry is the backstop.

### SSH keys

Each SSH key is an IAM resource. A change to `ssh_key_ids` on an Elastic Metal
server forces a reinstall. The consumer runbook records which key reaches which
host.

## Spend guardrails

| Guardrail                         | Kind                  | Effect                                  |
| --------------------------------- | --------------------- | --------------------------------------- |
| Per-Organization quotas           | Platform, hard        | Scaleway refuses to create the resource |
| Scoped IAM policies               | Platform, hard        | Scaleway refuses the action             |
| The monthly budget and its alerts | Platform, soft        | Scaleway sends a notification           |
| The pre-apply forecast check      | Pipeline              | The pipeline stops its own apply        |
| The idle watchdog                 | Pipeline, best effort | The pipeline destroys an idle stack     |

- **Quotas.** Ask Scaleway Support to set a quota of 1 for each compute offer
  that a stack declares, in `fr-par-2`.
- **Budget.** One monthly budget on the Organization. The consumer specification
  states the value. Only a human raises it. A Scaleway budget notifies; it does
  not block.
- **Alerts.** At 50, 75, and 100 percent of the budget, to email and to a CI
  webhook. Scaleway alerts on the amount after discount and tax.
- **Forecast check.** Before each apply, read
  `GET /billing/v2beta1/consumptions`. Stop the apply when the `updated_at`
  field is older than 6 hours, or when consumption plus the forecast of the run
  passes the budget. The forecast is the hourly price multiplied by the maximum
  lifetime of the run.
- **Idle watchdog.** `make infra-watchdog` runs every 30 minutes from CI, and
  every 30 minutes from a timer on the development host. A scheduled GitHub
  workflow alone is best effort.

A train stack is idle when it holds a server tagged
`<code>:lifecycle=ephemeral`, the server is older than 20 minutes, and the
heartbeat object is absent or older than 20 minutes. The training driver writes
the heartbeat every 60 seconds, and claims the stack once at start, with an
`If-None-Match: *` conditional write. The watchdog destroys the train stack when
the stack is idle, or when the time passes the `<code>:expires` tag. The
watchdog must report, and must not destroy, a resource with no `<code>:managed`
tag. The watchdog must never touch a resource tagged
`<code>:lifecycle=persistent`.

## Verification

- Trust the exit code of a CLI call, not the shape of its output. An error
  response can be valid JSON.
- Confirm each field path against real output before you parse it. A wrong path
  falls through a default silently.
- Confirm each removal with a read. A not-found result proves the removal.
- Do not assume a permission or a quota from a document. Probe the platform with
  an ephemeral resource, and record the result in the consumer runbook.
- An error from local name resolution proves nothing about platform access. Only
  a platform response proves authorization.

## Teardown

`tofu destroy` alone is not a teardown. A cancelled apply can create a resource
that never enters the state file, and that resource bills without limit.
`make infra-watchdog` reconciles the live resources against the state, and
reports each resource with no `<code>:managed` tag.

A destroy of `infra/train` must remove the server, the scratch volume, the root
volume, and the routed IPv4 address. Scaleway bills a reserved IPv4, attached or
not.

A resource in a transient state refuses a delete, and it bills during the wait.
Wait for a stable state, and delete it then. Test the delete path on a cheap
resource before you create an expensive one.

A full teardown runs in this order: `train`, `dev`, `image`, `persistent`. A
destroy of `persistent` surrenders the bucket names. Only a human runs it.

## Task runner

```
make infra-bootstrap            # the state bucket and its lifecycle rule — a human, once
make infra-fmt-check            # tofu fmt -recursive -check — no credential
make infra-validate STACK=name  # tofu validate — no credential
make infra-check                # infra-fmt-check, then infra-validate for each stack
make infra-plan STACK=name      # tofu plan — review what a session will create
make infra-plan-ro STACK=name   # tofu plan -lock=false — the pull-request plan
make infra-up STACK=name        # tofu apply — billing starts here
make infra-down STACK=name      # tofu destroy — billing stops here
make infra-status               # list live resources, so nothing idles unnoticed
make infra-price STACK=name     # print the hourly price of the stack compute
make infra-cost                 # month-to-date consumption against the budget
make infra-watchdog             # destroy an idle train stack; report an orphan
```

`make check` must call `make infra-check`, so a local run reproduces the CI
gate. Do not hardcode a price in the repository: read `hourly_price` from the
`scaleway_instance_server_type` data source, or the Product Catalog API for an
Elastic Metal offer.

## CI

| Trigger             | Job                                     | Credential         | Guard                                   |
| ------------------- | --------------------------------------- | ------------------ | --------------------------------------- |
| `pull_request`      | `tofu fmt -check`, `tofu validate`      | none               | Each pull request                       |
| `pull_request`      | `tofu plan -lock=false`                 | none, or read only | The branch is not a fork                |
| `push` to `main`    | `tofu apply` of `dev`, `train`, `image` | pipeline           | Environment `infra-apply`               |
| `workflow_dispatch` | Any action of `dev`, `train`, `image`   | pipeline           | Environment `infra-apply`               |
| `workflow_dispatch` | `tofu apply` of `infra/persistent`      | operator           | Environment `infra-admin`, human review |
| `schedule`          | Watchdog, reinstall                     | pipeline           | Environment `infra-apply`               |

- Do not use the `pull_request_target` trigger. Do not run a plan on a pull
  request from a fork: `tofu init` executes the provider binary that the branch
  names.
- The `infra-apply` environment must permit the `main` branch only. The
  `infra-admin` environment holds the operator key, behind a required human
  review.
- One concurrency group serializes each apply, per stack, with
  `cancel-in-progress: false` and `queue: max`. A cancelled apply can orphan a
  billed resource.
- Scaleway Audit Trail keeps 90 days of compute calls. A daily export writes
  each day to the artifacts bucket.
