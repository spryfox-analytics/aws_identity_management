# aws_identity_management

Terraform modules for the permission sets of AWS IAM Identity Center and their assignment to the
accounts of a customer and its projects. Version 2 contains only the role model for humans and AI
agents; the permission sets `view`, `dev`, `admin` and `support` stay in v1.x.

## Layout

The repository root holds no Terraform code. The two submodules are used directly:

| Module | Level | Purpose |
|---|---|---|
| `modules/permission_sets` | customer, once per Identity Center instance | creates `Viewer`, `AgentViewer`, `Developer`, `AgentDeveloper`, `Administrator` |
| `modules/assignments` | project (or customer) | assigns them to the groups `<prefix> Viewers`, `<prefix> Developers` and `<prefix> Administrators` |

```
source = "git::https://github.com/spryfox-analytics/aws_identity_management.git//modules/permission_sets?ref=v2.1.0"
source = "git::https://github.com/spryfox-analytics/aws_identity_management.git//modules/assignments?ref=v2.1.0"
```

Both need Terraform 1.5 or newer and the AWS provider 5.0 or newer.

## Role model

| Permission set | For | Session | Rights |
|---|---|---|---|
| `Viewer` | humans | 12 h | ViewOnlyAccess plus operational read |
| `AgentViewer` | AI agents | 1 h | as `Viewer` |
| `Developer` | humans | 12 h | `Viewer`, everything in `development_account_numbers`, start, retry, stop and approve pipelines in `pipeline_account_numbers` |
| `AgentDeveloper` | AI agents | 1 h | `Viewer`, everything in `agent_development_account_numbers` (default: `development_account_numbers`), start, retry and stop pipelines in `pipeline_account_numbers`, with the denials below |
| `Administrator` | humans | 1 h | AdministratorAccess, for the exceptions: first setup and console-only tasks (activating connections, support cases); no agent counterpart |

One permission set gives the same role in every account, so the rights of `Developer` and
`AgentDeveloper` follow from conditions on the account of the role (`aws:PrincipalAccount`). In all
other accounts they have the rights of `Viewer`; deployments there go through the approved pipelines.

ViewOnlyAccess shows the configuration of the services but no data: no object contents, table
items, secrets or parameters. The inline policy "operational read" adds what is needed to follow
and debug a running system:

- CloudWatch Logs: `Describe*`, `Get*`, `List*`, `FilterLogEvents`, `StartQuery`, `StopQuery`,
  `GetQueryResults`, `StartLiveTail`
- CloudWatch metrics and alarms: `Describe*`, `Get*`, `List*`
- CodeBuild `BatchGet*`, `List*` and CodePipeline `Get*`, `List*` (build logs via CloudWatch Logs)
- CloudTrail `LookupEvents` (event history)
- X-Ray `BatchGet*`, `Get*`, `List*`
- CloudFront `Get*`, `List*`
- API Gateway `GET`, except API keys (`/apikeys`), whose values are secrets
- Lambda configuration (`GetFunctionConfiguration`, `GetPolicy`, `GetAlias`, concurrency, URL and
  event source settings, `List*`); not `GetFunction` and `GetLayerVersion`, which hand out the code
- DynamoDB `Describe*`, `List*`; no `GetItem`, `Query` or `Scan`
- S3 `GetBucket*`, encryption, lifecycle and replication configuration, `ListAllMyBuckets`,
  `ListBucket`; no `GetObject`
- Step Functions `Describe*`, `List*`, `GetExecutionHistory`
- ECS `Describe*`, `List*`
- EventBridge `Describe*`, `List*` and EventBridge Scheduler `Get*`, `List*`

Some of these show values that are not meant as data but can contain it: environment variables of
Lambda functions and ECS task definitions, and the input and output of Step Functions executions.
Secrets belong in Secrets Manager or Parameter Store, not there.

`AgentDeveloper` is denied everywhere, also in its development accounts:

- `codepipeline:PutApprovalResult`: approvals are for humans only.
- `iam:CreateUser`, `iam:CreateAccessKey`, `iam:CreateLoginProfile`, `iam:UpdateLoginProfile`,
  `iam:CreateServiceSpecificCredential`, `iam:UploadSSHPublicKey`: no long-lived credentials with
  which an agent could act outside its role.
- `sso:*`, `sso-directory:*`, writes to `identitystore`, `organizations` and `account`.

### Humans and agents

- **Attribution**: an agent's session is the role `AWSReservedSSO_AgentViewer_*` or
  `AWSReservedSSO_AgentDeveloper_*`. CloudTrail tells every action of an agent apart from the
  actions of the human it works for, also when both are the same user in the identity store.
- **No approvals**: a pipeline approval stays a human decision. An agent can run a pipeline up to
  the approval, not past it.
- **Short sessions**: one hour instead of twelve limits what a leaked or misused session can do.
- **Own development accounts**: `agent_development_account_numbers` can restrict agents to a part of
  the development accounts.
- **No administration**: `Administrator` exists for humans only. Its group stays small and is used
  for the exceptions; the daily work runs with `Developer`, and an agent never gets the
  `Administrator` profile in its sandbox.

The roles only help if the agent cannot reach the human credentials. Agents should run in a
sandbox that sees only the AWS profiles of the agent roles (for example a separate AWS config with
only `AgentViewer`/`AgentDeveloper` profiles and its own SSO token cache). That setup belongs to the
workstation and is not part of these modules.

## Usage

### permission_sets

Once per Identity Center instance, usually in the management account of the customer:

```hcl
module "permission_sets" {
  source                      = "git::https://github.com/spryfox-analytics/aws_identity_management.git//modules/permission_sets?ref=v2.1.0"
  development_account_numbers = ["222222222222"]
  pipeline_account_numbers    = ["333333333333"]
  # optional
  agent_development_account_numbers = ["222222222222"] # default: development_account_numbers
  session_duration_humans           = "PT12H"
  session_duration_agents           = "PT1H"
  name_prefix                       = ""               # names are exactly Viewer, AgentViewer, ...
  relay_state                       = null             # console start page
  tags                              = {}
}
```

Outputs: `permission_set_arns` and `permission_set_names` (maps keyed by role), and
`viewer_arn`, `agent_viewer_arn`, `developer_arn`, `agent_developer_arn`.

### assignments

Per project (or once for the customer with the customer's groups), after the permission sets exist:

```hcl
module "project_permissions" {
  source                     = "git::https://github.com/spryfox-analytics/aws_identity_management.git//modules/assignments?ref=v2.1.0"
  group_prefix               = "Spryfox Skillmoor"
  viewers_account_numbers    = ["222222222222", "333333333333", "444444444444"]
  developers_account_numbers = ["222222222222", "333333333333", "444444444444"]
  # Optional: full access for the exceptions, for a small group.
  administrators_account_numbers = ["222222222222", "333333333333", "444444444444"]
}
```

| Group | Permission sets per account |
|---|---|
| `<group_prefix> Viewers` | `Viewer`, `AgentViewer` |
| `<group_prefix> Developers` | `Viewer`, `AgentViewer`, `Developer`, `AgentDeveloper` |

The module looks the permission sets up by name (`aws_ssoadmin_permission_set`) and the groups by
display name (`aws_identitystore_group`), each only when an assignment needs it. Both must exist
before the apply. At Spryfox the groups come from Entra ID via SCIM provisioning. With a
`name_prefix` in `permission_sets`, pass its `permission_set_names` output (or the names) as
`permission_set_names`; missing roles keep their default name.

Outputs: `group_ids`, `permission_set_arns` and `assignments` (keyed by `<group>/<account>/<role>`).

## Migrating from v1

v2 creates nothing named `view`, `dev`, `admin` or `support`, so v1 and v2 can run side by side.

1. **Customer stack**: keep the v1 module block and add a `permission_sets` v2 block next to it.
   If the stack used `agent_aware_roles = true` of v1.2.0, set it to false in the same change: the
   permission sets `Viewer`, `AgentViewer`, `Developer` and `AgentDeveloper` would otherwise exist
   twice. Plain renaming is not possible because the names are unique per Identity Center instance;
   either remove the v1.2.0 sets first (their assignments go with them) or move them into the v2
   module with `moved` blocks from `module.<v1>.aws_ssoadmin_permission_set.agent_aware["<role>"]`
   to `module.<v2>.aws_ssoadmin_permission_set.this["<role>"]` (likewise for
   `aws_ssoadmin_managed_policy_attachment` and `aws_ssoadmin_permission_set_inline_policy`, whose
   v2 addresses are `view_only_access` and `this`).
2. **Projects**: for each project, add an `assignments` v2 block with the project's groups and
   accounts. Once the groups work with the new roles, remove the view/dev/admin/support assignments
   from that project's v1 block (or the whole v1 block of the project).
3. **Finally**: when no project assigns the old permission sets any more, drop the v1 block from
   the customer stack. This deletes `view`, `dev`, `admin` and `support`.

The old `admin` corresponds to `Administrator` (since v2.1.0, with one-hour sessions); `support`
has no counterpart. Accounts that still need it keep a v1 block or get their own permission set.

## Changes

- **v2.1.0**: permission set `Administrator` (AdministratorAccess, humans only, 1 h,
  `session_duration_administrators`) and the group `<prefix> Administrators` in `modules/assignments`
  (`administrators_account_numbers`). Output `administrator_arn`.
- **v2.0.0**: new major without backwards compatibility. Only the role model `Viewer`,
  `AgentViewer`, `Developer`, `AgentDeveloper`, split into the submodules `modules/permission_sets`
  and `modules/assignments`. Removed: the permission sets `view`, `dev`, `admin` and `support`, the
  customer/project switch via `project_name`, `aws_region`, `customer_name` (now `group_prefix`)
  and the external script for the ARN lookup (replaced by the data source
  `aws_ssoadmin_permission_set`). Session durations, name prefix, relay state and tags are inputs.
  The opt-in role model of v1.2.0 is superseded by v2.0.0. Needs Terraform 1.5 and AWS provider 5.0.
- **v1.2.0**: opt-in role model for humans and agents (`agent_aware_roles`) next to the old sets.
- **v1.1.0**: `dev` gets its rights from `development_account_numbers`, `pipeline_account_numbers`
  and the Athena rights of `view`.
