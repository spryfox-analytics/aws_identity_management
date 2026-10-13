# aws_identity_management

Terraform module for the permission sets of AWS IAM Identity Center and their assignment to the
accounts of a customer and its projects.

## Levels

- **Customer level** (no `project_name`): creates the permission sets `view`, `dev`, `admin` and
  `support` once for the organisation and assigns the customer's groups to the given accounts.
- **Project level** (`project_name` set): finds the permission sets by name and assigns the groups
  `<customer> <project> Administrators`, `Developers`, `Viewers` and `Support Agents` to the
  project's accounts.

## Permission sets

| Permission set | Rights |
|---|---|
| `view` | ReadOnlyAccess plus Athena queries |
| `dev` | the role for daily work, see below |
| `admin` | AdministratorAccess, for the exceptions |
| `support` | AWSSupportAccess |

### dev

One permission set gives the same role in every account, so the rights of `dev` follow from
conditions on the account of the role. At customer level:

- `development_account_numbers`: here `dev` may do everything, as `admin`.
- `pipeline_account_numbers`: here `dev` may approve, retry, start and stop CodePipeline pipelines,
  usually the tools accounts.
- everywhere else `dev` may read and query with Athena, as `view`. Deployments to these accounts go
  through the approved pipelines.

Without these lists `dev` has the rights of `view`. `development_inline_policy_json` replaces the
whole inline policy for customers whose developers need other rights.

```hcl
module "permission_sets" {
  source                      = "git::https://github.com/spryfox-analytics/aws_identity_management.git?ref=v1.1.0"
  aws_region                  = "eu-west-1"
  customer_name               = "My Customer"
  administrators_account_numbers = ["111111111111"]
  development_account_numbers = ["222222222222"]
  pipeline_account_numbers    = ["333333333333"]
}
```

## Role model for humans and agents

With `agent_aware_roles = true` the customer level creates four more permission sets. `view`, `dev`,
`admin` and `support` stay as they are; without the variable nothing changes.

| Permission set | For | Session | Rights |
|---|---|---|---|
| `Viewer` | humans | 12 h | ViewOnlyAccess plus operational read |
| `AgentViewer` | AI agents | 1 h | as `Viewer` |
| `Developer` | humans | 12 h | `Viewer`, everything in `development_account_numbers`, start, retry, stop and approve pipelines in `pipeline_account_numbers` |
| `AgentDeveloper` | AI agents | 1 h | `Viewer`, everything in `agent_development_account_numbers` (default: `development_account_numbers`), start, retry and stop pipelines in `pipeline_account_numbers`, with the denials below |

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

### Why agents have their own roles

- **Attribution**: an agent's session is the role `AWSReservedSSO_AgentViewer_*` or
  `AWSReservedSSO_AgentDeveloper_*`. CloudTrail tells every action of an agent apart from the
  actions of the human it works for, also when both are the same user in the identity store.
- **No approvals**: a pipeline approval stays a human decision. An agent can run a pipeline up to
  the approval, not past it.
- **Short sessions**: one hour instead of twelve limits what a leaked or misused session can do.
- **Own development accounts**: `agent_development_account_numbers` can restrict agents to a part of
  the development accounts.

The roles only help if the agent cannot reach the human credentials. Agents should run in a
sandbox that sees only the AWS profiles of the agent roles (for example a separate AWS config with
only `AgentViewer`/`AgentDeveloper` profiles and its own SSO token cache). That setup belongs to the
workstation and is not part of this module.

### Usage

Customer level:

```hcl
module "permission_sets" {
  source                      = "git::https://github.com/spryfox-analytics/aws_identity_management.git?ref=v1.2.0"
  aws_region                  = "eu-west-1"
  customer_name               = "My Customer"
  development_account_numbers = ["222222222222"]
  pipeline_account_numbers    = ["333333333333"]
  agent_aware_roles           = true
  # optional, default development_account_numbers
  agent_development_account_numbers = ["222222222222"]
}
```

Project level, after the customer level has created the permission sets:

```hcl
module "project_permissions" {
  source                          = "git::https://github.com/spryfox-analytics/aws_identity_management.git?ref=v1.2.0"
  aws_region                      = "eu-west-1"
  customer_name                   = "My Customer"
  project_name                    = "My Project"
  role_viewers_account_numbers    = ["222222222222", "333333333333", "444444444444"]
  role_developers_account_numbers = ["222222222222", "333333333333", "444444444444"]
}
```

`role_viewers_account_numbers` gives the group `<customer> <project> Viewers` the permission sets
`Viewer` and `AgentViewer`, `role_developers_account_numbers` gives the group
`<customer> <project> Developers` `Developer`, `AgentDeveloper`, `Viewer` and `AgentViewer`. Both
work at customer level too (groups `<customer> Viewers` and `<customer> Developers`, there only with
`agent_aware_roles = true`). They can be combined with `viewers_account_numbers` and
`developers_account_numbers`; the same group then has `view` and `dev` next to the new sets.

The groups must exist in the identity store before the apply, the module only looks them up. At
Spryfox they come from Entra ID via SCIM provisioning. At project level the module looks the
permission sets up by name only when one of the two lists is set; the outputs of the new permission
sets are null otherwise.

## Changes

- **v1.2.0**: role model for humans and agents: `agent_aware_roles`,
  `agent_development_account_numbers`, `role_viewers_account_numbers`,
  `role_developers_account_numbers` and the outputs `permission_set_viewer_arn`,
  `permission_set_agent_viewer_arn`, `permission_set_developer_arn`,
  `permission_set_agent_developer_arn`. All default to the old behaviour. Needs Terraform 1.2 or
  newer (preconditions).
- **v1.1.0**: `dev` gets its rights from `development_account_numbers`, `pipeline_account_numbers`
  and the Athena rights of `view`; before, it had ReadOnlyAccess only and projects added their own
  inline policy. A project that set the inline policy of `dev` itself has to stop doing so (for
  example with a `removed` block that keeps the policy), otherwise both overwrite each other.
