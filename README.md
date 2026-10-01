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

## Changes

- **v1.1.0**: `dev` gets its rights from `development_account_numbers`, `pipeline_account_numbers`
  and the Athena rights of `view`; before, it had ReadOnlyAccess only and projects added their own
  inline policy. A project that set the inline policy of `dev` itself has to stop doing so (for
  example with a `removed` block that keeps the policy), otherwise both overwrite each other.
