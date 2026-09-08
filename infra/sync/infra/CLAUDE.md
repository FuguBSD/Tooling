<!--
The infra pack of FuguBSD/Tooling owns this file. Do not edit a synced
copy. Edit the canonical copy in FuguBSD/Tooling.
-->

# Shared infrastructure instructions

The shared rules for the OpenTofu code under `infra/`. The design behind these
rules lives at <https://github.com/FuguBSD/Tooling/blob/main/spec/infra.md>. The
consumer specification states the project resources, the budget, and the
documented exceptions. `<code>` is the project short code, in lower case, and
the consumer specification states it.

## Ground rules

- OpenTofu declares each resource. Do not make a resource in the console.
- The infrastructure code has the ISC license.
- The shared platform is Scaleway. A consumer can manage an other platform under
  `infra/`, for example GitHub.
- The Scaleway rules of this file apply to each stack that declares a Scaleway
  resource.
- Read the live price before you create a resource. Each recorded price carries
  the date it was read.
- Scaleway documents a minimum of 60 minutes for each created resource, so a
  cycle shorter than one hour saves nothing.

## Naming

The naming rule lives in the Repositories specification (Repositories
SET-NAMING-1).

- Each Scaleway resource name must use the pattern `<project>.<env>.<thing>`,
  for example `<code>.prod.train`.
- Each bucket name must use the pattern `<code>-<purpose>-<suffix>`, because a
  bucket name is unique across the whole platform.
- The bootstrap runbook of the consumer records the bucket name suffix.

## Region and zone

| Item                    | Value                         |
| ----------------------- | ----------------------------- |
| Region                  | `fr-par`                      |
| Zone                    | `fr-par-2`                    |
| Object Storage endpoint | `https://s3.fr-par.scw.cloud` |

- One region and one zone hold everything.
- Do not put a bucket in a second region.

## Version pins

| Tool              | Constraint                       |
| ----------------- | -------------------------------- |
| OpenTofu          | `required_version = ">= 1.11.0"` |
| Scaleway provider | `version = "~> 2.80"`            |

- Each stack must hold a `versions.tf` with both constraints.
- Each stack must commit its `.terraform.lock.hcl`.
- A stack must not use `action` resources or list resources: OpenTofu supports
  neither.

## Stacks

- The four stack names are fixed: `persistent`, `dev`, `train`, and `image`.
- Each stack is a root module, and must hold `versions.tf`, `backend.tf`,
  `providers.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, and its committed
  lock file.
- A stack must not read the state of another stack with
  `terraform_remote_state`.
- A stack must not contain a hardcoded Scaleway UUID. Resolve each identifier
  with a data source.
- Create a module only when a pattern has three or more callers.

## Tags

- Each stack must tag each resource it creates.
- An instance takes a list of strings, and a bucket takes a map. Build both
  shapes from one map in `locals.tf`.

| Tag                | Example                               | Purpose                             |
| ------------------ | ------------------------------------- | ----------------------------------- |
| `<code>:stack`     | `<code>:stack=train`                  | Names the owning stack              |
| `<code>:managed`   | `<code>:managed=true`                 | Marks a resource the pipeline owns  |
| `<code>:lifecycle` | `<code>:lifecycle=ephemeral`          | The watchdog reaps `ephemeral` only |
| `<code>:run-id`    | `<code>:run-id=8891fa2c`              | Ties a resource to one CI run       |
| `<code>:expires`   | `<code>:expires=2026-08-02T18:00:00Z` | The hard end of the lease, in UTC   |

- An ad-hoc resource — a probe, an experiment — must carry
  `<code>:lifecycle=ephemeral` and a near `<code>:expires`.
- Delete an ad-hoc resource in the same session. The watchdog is the backstop.

## Buckets

The consumer specification states the bucket set and the versioning of each
bucket.

- No bucket is public. Each bucket keeps the default private ACL.
- Set `force_destroy = false` on each bucket.
- A lifecycle rule must abort an incomplete multipart upload after one day.
  Scaleway bills an incomplete upload.
- Object lock must stay off. Object lock cannot be disabled again.

## State

- State lives in a dedicated Object Storage bucket, through the S3-compatible
  backend.
- Each stack keeps its own state key.
- The backend must set `use_lockfile = true`: the bucket holds a native lock.
- `tofu apply` must not set `-lock=false`.
- A pull-request plan must set `-lock=false`, because a plan writes no state.
- Use `endpoints = { s3 = ... }` and `use_path_style`. The arguments `endpoint`
  and `force_path_style` are deprecated.
- The backend block must not hold a key.
- The backend takes its credential from the environment, or from the
  `~/.aws/credentials` profile that `AWS_PROFILE` names.
- OpenTofu must encrypt the state and the plan.
- A bucket policy on the state bucket must name each principal that needs the
  bucket, and no other principal.
- OpenTofu must not create an API key. A managed key writes its secret to state.

## Credentials

- The persistent stack declares each IAM application and each policy.
- Every local `scw` command must name its profile: `scw --profile <profile> ...`
  on a command line, or `SCW_PROFILE=<profile>` for a script. No profile is
  active by default, so a command with no profile fails loudly.
- The S3 tools must take `AWS_PROFILE=<profile>`.
- The tofu provider must take `SCW_PROFILE` or a `profile` argument.
- Keep the credential variables out of the local shell: the environment beats a
  profile in every Scaleway tool.
- The profile selectors carry no secret.
- A wrong identity can look correct, so treat an authentication failure first as
  an expired key.
- CI must export exactly one credential set, as environment variables.
- The `provider` block must not set `access_key`, `secret_key`, or `project_id`.
- A rotation is a create and a delete, because Scaleway cannot change the expiry
  of a key.
- The train key must not touch OpenTofu, `user_data`, or state. `user_data` is
  readable through the instance API.

## Spend guardrails

- Ask Scaleway Support to set a quota of 1 for each compute offer that a stack
  declares, in `fr-par-2`.
- One monthly budget covers the Organization.
- Only a human raises the monthly budget.
- Read the consumption before each apply.
- Stop the apply when the `updated_at` field of the consumption is older than 6
  hours.
- Stop the apply when the consumption plus the forecast of the run passes the
  budget.
- The watchdog must report, and must not destroy, a resource with no
  `<code>:managed` tag.
- The watchdog must never touch a resource tagged `<code>:lifecycle=persistent`.

## Verification

- Trust the exit code of a CLI call, not the shape of its output. An error
  response can be valid JSON.
- Confirm each field path against real output before you parse it. A wrong path
  falls through a default silently.
- Confirm each removal with a read. A not-found result proves the removal.
- Do not assume a permission or a quota from a document. Probe the platform with
  an ephemeral resource.
- Record each probe result in the consumer runbook.
- An error from local name resolution proves nothing about platform access. Only
  a platform response proves authorization.

## Teardown

- `make infra-watchdog` reconciles the live resources against the state.
- A destroy of `infra/train` must remove the server, the scratch volume, the
  root volume, and the routed IPv4 address.
- A resource in a transient state refuses a delete, and it bills during the
  wait. Wait for a stable state, and delete it then.
- Test the delete path on a cheap resource before you create an expensive one.
- A full teardown runs in this order: `train`, `dev`, `image`, `persistent`.
- Only a human destroys `persistent`.

## Task runner

- `make check` must call `make infra-check`, so a local run reproduces the CI
  gate.
- Do not hardcode a price in the repository.
- Read `hourly_price` from the `scaleway_instance_server_type` data source, or
  the Product Catalog API for an Elastic Metal offer.

## CI

- Do not use the `pull_request_target` trigger.
- Do not run a plan on a pull request from a fork. `tofu init` executes the
  provider binary that the branch names.
- The `infra-apply` environment must permit the `main` branch only.
- The `infra-admin` environment holds the operator key.
- A required human review must guard the `infra-admin` environment.
- One concurrency group serializes each apply, per stack, with
  `cancel-in-progress: false` and `queue: max`. A cancelled apply can orphan a
  billed resource.
