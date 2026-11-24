# Deploying the dev workload

The manual **Terraform Apply** workflow produces and applies a saved plan for the default workspace in `ap-south-1`. Each operation requires a separate dispatch from the same `main` commit and admission to the `terraform-apply` environment. The existing **Terraform Plan** workflow remains available for advisory plans.

## Before enabling deployment

- A bootstrap operator owns the GitHub OIDC provider, all three CI identities and their policies/attachments. Review a fresh, untargeted plan under trusted operator credentials. The expected IAM rollout updates the existing Plan and Apply policies in place, creates the companion network policy, and attaches it to the existing Apply role. Preserve the managed policy ARN, the trust conditions and the ECR repository. If that plan includes workload creates, do not execute it as a bootstrap-only change. Prepare a separately approved, IAM-only bootstrap operation and reconcile with another untargeted plan. The workflow rejects pending root IAM changes before provisioning.
- The live Apply trust checked on 24 November 2026 required the GitHub provider, STS audience, the exact repository-ID/owner-ID subject for `terraform-apply`, `refs/heads/main`, and workflow name `Terraform Apply`. GitHub allowed only branch `main` in this environment. It had one required reviewer, allowed self-review and admin bypass, and `main` was unprotected. Protect deployment code with required review and arrange an independent environment reviewer before enabling workload writes. The workflow display name alone does not identify immutable code.
- Configure a randomly generated, high-entropy, single-line `TF_PLAN_PASSPHRASE` as a secret on **terraform-apply**, and provide it to authorized plan reviewers through a secret manager. The repository is public. Only encrypted plans may leave the runner. Rotate the secret after exposure and discard pending artifacts. Rotation cannot protect artifacts already downloaded with a compromised key.
- Verify the existing ECS, Elastic Load Balancing and ECS Application Auto Scaling service-linked roles. Their first-time creation is an operator prerequisite. Review the selected release's current scan and intended run window. NAT gateway hours/processing, ALB hours/LCUs, Fargate, public IPv4 addresses, CloudWatch and data transfer can incur charges.

## Review and apply

1. Dispatch **Terraform Apply** on `main` with operation `plan` and leave both identifiers empty. The environment gate runs first. The planning session has read access plus the native S3 lock permissions. Terraform 1.16.4 initializes using the tracked provider lockfile, validates, then generates one normal locked plan. The summary lists changed addresses, actions, commit, run ID and plaintext SHA-256. A successful run retains an encrypted plan for one day.
2. Inspect the **actual plan** on a trusted machine using the same commit, Terraform CLI and locked providers. Run these commands from the repository root. Supply the passphrase at the GPG prompt. Keep the temporary directory private and remove it after review. The human-readable plan can contain sensitive values.

   ```bash
   umask 077
   review_dir=$(mktemp -d)
   gh run download "$PLAN_RUN_ID" -n "dev-plan-$PLAN_RUN_ID" -D "$review_dir"
   gpg --output "$review_dir/dev.tfplan" --decrypt "$review_dir/dev.tfplan.gpg"
   shasum -a 256 "$review_dir/dev.tfplan"
   TF_DATA_DIR="$review_dir/tfdata" terraform -chdir=environments/dev init -backend=false -lockfile=readonly
   TF_DATA_DIR="$review_dir/tfdata" terraform -chdir=environments/dev show -no-color "$review_dir/dev.tfplan"
   ```

3. Compare the hash with the run summary. Review IAM trust, policy attachments, SG sources, routes, replacements/deletes, ECS digest, alarms and cost. Confirm that the retained ECR repository and CI IAM resources have zero changes. The image lookup checks the immutable tag against the pinned index digest in `environments/dev/main.tf`; ECS receives a digest reference. The selected index contained a Linux amd64 manifest when checked on 24 November 2026.
4. Dispatch **Terraform Apply** again with operation `apply`, the successful planning run ID and the hash you reviewed. The reviewer should check those inputs in the dispatch event against the first run before approving the environment. The workflow checks run provenance, age, current main SHA, plan bytes and the workload boundary. Terraform takes the S3 lock and applies only the saved binary. A newer state serial, different lineage, expired artifact or changed commit requires a new plan. Runs are serialized and in-progress applies are never canceled by concurrency settings.
5. After an error, inspect state, CloudTrail and the affected service before generating a fresh plan. Terraform can persist partial changes. Out-of-band changes that leave the state serial untouched may escape saved-plan staleness detection. Following success, verify ECS service stability, running image digest, target health, HTTP 200 from `/health`, logs and an untargeted reconciliation plan. Budget approval and a teardown owner are required for the deployment window.

## Permission inventory

The HCL action lists are the reference for the delegated operations. Both policies attach to `GithubActions-Terraform-Apply-Role`. Splitting network permissions keeps each managed policy within the 6,144-character quota. The inherited Plan policy statements provide provider discovery and refresh, including EC2, ELB, ECS and autoscaling Describe/List families and IAM role/policy reads. Some of those existing reads span the account.

| Module | Lifecycle and authorization scope |
| --- | --- |
| networking | EC2 create/delete VPCs, subnets, internet and NAT gateways, EIPs and route tables. Modify VPC/subnet attributes, attach/detach gateways, allocate/release addresses, create/replace/delete routes, associate/replace/disassociate route tables and manage tags. EC2 assigns IDs. New resources require the `CapstoneStack` request tag. Existing objects used by multi-resource APIs and later edits/deletes require the ownership tag. The aliased provider supplies it to this module and security. |
| security | Create/delete tagged groups, authorize/revoke ingress and egress including the default egress rule, modify rules and reconcile tags. A standalone rule create authorizes both the tagged parent group and the new rule. EC2 Describe covers refresh. |
| iam | Create/read/update/delete and tag only `dev-ecs_execution_role`. Attach/detach requires the exact AWS-managed `AmazonECSTaskExecutionRolePolicy` ARN. PassRole requires this role ARN and `iam:PassedToService = ecs-tasks.amazonaws.com`. The module supplies the ECS task trust. An execution-role trust change deserves human review because IAM cannot constrain the contents of a proposed trust document with this grant. |
| ecr | DescribeRepositories, ListTagsForResource and repository-scoped DescribeImages cover the retained repository and release check. Repository create/delete, PutImageScanningConfiguration, PutImageTagMutability, TagResource and UntagResource are operator-owned lifecycle APIs. The workflow rejects **any** managed ECR change. Publishing and image deletion are outside Apply. |
| alb | Describe resources/attributes/tags. Create/modify/delete the named ALB, its listeners and target group, including subnets, security groups, attributes and tags. ECS handles target registration. |
| compute | Create/update/delete the named cluster and service, register revisions of the task family, deregister revisions, and manage tags. The named log group permits create/delete, retention and tagging. AWS defines no resource scope for DeregisterTaskDefinition, so the grant covers Mumbai revisions. The role can deploy application code and spend within its delegated resource scope. |
| monitoring | Register/update/deregister scalable targets, put/delete target-tracking policies and read tags on generated target ARNs. Writes require the ECS namespace and desired-count dimension in this account/region. These conditions can match other ECS scalable targets. CloudWatch alarm writes and tags use the exact service memory alarm ARN. Application Auto Scaling owns target-tracking alarms. |

The network tag is an authorization boundary for existing resources. Reserve its value for this stack. An operator must reconcile previously created, untagged network resources before this role can manage them. The deployer can edit tags on already-owned resources. A changed or removed ownership tag can strand the resource.

## Bootstrap authority and state

Apply can refresh its own role, but an explicit deny covers non-read actions on its role and both of its attached customer policies. It has no managed-policy authoring, inline-policy authoring, OIDC-provider administration, arbitrary role attachment or service-linked-role creation grant. The dedicated execution role is its only IAM write target. Keep additional policies off the Apply role. The AWS policy is the enforcement point even for calls outside Terraform.

The current dev state includes the GitHub roles, policies and attachments alongside ECR and the workload. The workflow rejects a managed change outside the workload modules, including a proposed create for a missing CI identity. Only the bootstrap owner can reconcile those objects. State writers can still forge state, and malicious repository code can replace workflow checks. A privileged operator must independently reconcile configuration, state identifiers and live AWS identities before authorizing bootstrap work. Never feed a CI-provided plan to a more privileged identity.

For a single-owner lab this management boundary permits an IAM-limited deployment without changing state ownership. Independent deployment and IAM administration require **separate bootstrap state**, with its own access controls and a bootstrap-only root, before treating workload writers as untrusted. Inventory and back up both states, stop writers, transfer each CI address exactly once under separate approval, and verify both untargeted plans. The OIDC provider and backend bucket already have independent lifecycles. This implementation performs no state transfer.

The backend remains the dedicated `tfstate-vaibhav-capstone-207224908189-aps1` bucket. Plan and Apply can list the dev key, its lock key and the exact default workspace discovery prefix `env:/`. Listing this prefix can expose workspace key names. Object access covers only `terraform-aws-capstone/dev/terraform.tfstate` (Get, also Put for Apply) and its `.tflock` sibling (Get/Put/Delete). The role cannot delete state, administer the bucket or access another workspace's objects through these grants. S3 locking serializes state access during individual Terraform operations. It does not reserve infrastructure between review and apply. Lock contention, recovery and end-to-end deployment still need an approved exercise.

References include the [HashiCorp S3 backend permissions](https://developer.hashicorp.com/terraform/language/backend/s3), [AWS service authorization reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html), and [Terraform saved plan handling](https://developer.hashicorp.com/terraform/cli/commands/plan#out-filename).
