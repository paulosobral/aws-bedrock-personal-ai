# AWS Bedrock Personal AI

Infrastructure as code (Terraform) to provision secure and monitored access to Amazon Bedrock, with least-privilege IAM and cost/usage alarms.

## What this project provisions

### `iam_role` module
- **Dedicated IAM User** (`/bedrock/`) exclusively for Bedrock usage, with its own Access Key.
- **IAM Role** that can only be assumed by the dedicated user itself (trust policy restricted by `aws:PrincipalArn`).
- **Least-privilege policy** attached to the role: allows `bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`, `bedrock:ListFoundationModels`, `bedrock:ListInferenceProfiles`, and minimal AWS Marketplace actions (required to subscribe to third-party models on Bedrock); denies any `iam:*` action besides `PassRole`.
- **Optional Permission Boundary** that strictly limits the role to Bedrock actions, even if future policies are attached by mistake.
- **Optional multi-region CloudTrail** for auditing all calls to Bedrock.

### `cost_alarm` module
- **SNS Topic** with an email subscription for alerts.
- **Monthly AWS Budget** filtered by the "Amazon Bedrock" service, with notification when a percentage of the limit is reached.
- **CloudWatch Alarms** (individually enable-able):
  - Token consumption (`AWS/Bedrock` `TokenCount`)
  - Number of invocations (`AWS/Bedrock` `Invocations`)
  - Accumulated cost (`AWS/Billing` `EstimatedCost`)

## Structure

```
.
├── main.tf                  # AWS provider, S3 backend and module calls
├── variables.tf             # Project variables (with defaults)
├── outputs.tf                # Consolidated module outputs
├── modules/
│   ├── iam_role/             # User, Role, policies, boundary and CloudTrail
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── cost_alarm/           # SNS, Budgets and CloudWatch alarms
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── bedrock-cost-report.sh    # Standalone script: estimates monthly cost from CloudWatch metrics
└── .gitignore
```

## Prerequisites

### Tools

| Tool | Version | Use in project | Installation |
|---|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform) | `>= 1.6` | Provision all the infra (IAM, SNS, Budgets, CloudWatch, CloudTrail) | [Download](https://developer.hashicorp.com/terraform/install) |
| [AWS CLI](https://aws.amazon.com/cli/) | `v2` | Authentication (`aws configure`), assume-role validation and Bedrock calls | [Installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| [Node.js](https://nodejs.org/) | `>= 18` | Required to install Claude Code via `npm` | [Download](https://nodejs.org/) |
| [Claude Code](https://www.npmjs.com/package/@anthropic-ai/claude-code) | `2.1.92` | Client that consumes Bedrock (optional, see [Consuming the resources](#consuming-the-resources-client-setup) section) | `npm install -g @anthropic-ai/claude-code@2.1.92` |
| AWS Provider (Terraform) | `~> 5.0` | Automatically installed by `terraform init` | — |

### AWS account and access

- AWS account with configured credentials (`aws configure` or the `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN` environment variables) and permission to create IAM, SNS, Budgets, CloudWatch and (optionally) CloudTrail resources.
- An existing S3 bucket for the Terraform remote backend (`terraform-state-bedrock-psobral89`) and, if `enable_cloudtrail = true`, an S3 bucket for the CloudTrail logs.
- Access enabled for the desired models in the [Bedrock console (Model access)](https://console.aws.amazon.com/bedrock/) — this is done manually by AWS and is not provisioned by Terraform.
- Current model pricing: [aws.amazon.com/bedrock/pricing](https://aws.amazon.com/bedrock/pricing/).

## Usage

```bash
# Initialize the backend and providers
terraform init

# View the execution plan
terraform plan

# Apply the changes
terraform apply
```

To destroy the resources:

```bash
terraform destroy
```

## Main variables

All variables have default values in `variables.tf`. The most relevant ones to customize:

| Variable | Description | Default |
|---|---|---|
| `bedrock_role_name` | IAM Role name | `bedrock-user-psobral89-role` |
| `notification_email` | Email for cost alerts | `paulo.sobral@outlook.com.br` |
| `budget_limit` | Monthly budget limit (USD) | `50.0` |
| `notification_threshold` | % of the budget to notify | `80.0` |
| `enable_cloudtrail` | Enables auditing via CloudTrail | `true` |
| `cloudtrail_bucket_name` | S3 bucket for CloudTrail logs | `cloudtrail-logs-bedrock-psobral89` |
| `enable_token_alarm` / `token_threshold` | Token consumption alarm | `true` / `100000` |
| `enable_invocation_alarm` / `invocation_threshold` | Invocation count alarm | `true` / `1000` |
| `enable_cost_alarm` / `cost_threshold` | Accumulated cost alarm (USD) | `true` / `10.0` |

To override, create a `terraform.tfvars` (ignored by `.gitignore`) or pass `-var` on the command line.

## Outputs

After `apply`, the main available outputs include `bedrock_role_arn`, `bedrock_user_arn`, `sns_topic_arn`, `budget_arn` and the names of the created alarms. The credentials (`bedrock_access_key_id` and `bedrock_secret_access_key`) are marked as `sensitive` — use `terraform output -raw <name>` to display them.

## Cost report script (`bedrock-cost-report.sh`)

Standalone bash script that estimates how much you'll pay in the current month for the Bedrock models you actually used, based on real CloudWatch metrics.

What it does:
- Discovers, via `aws cloudwatch list-metrics`, which model IDs generated `InputTokenCount`/`OutputTokenCount` since the 1st of the current month.
- For each model, sums input/output tokens in the period via `aws cloudwatch get-metric-statistics`.
- Resolves the USD price per 1M tokens in this order: local cache (`.pricing_cache.json`) → `aws pricing get-products` (only covers legacy models like Claude 2.x/3, since current Claude models are sold via AWS Marketplace and aren't exposed by this API) → interactive prompt, which then gets saved to the cache with an `updated_at` timestamp for reuse on the next run.
- Prints cost per model (input/output/total) and the total for the month.

Requirements: `aws` CLI, `jq`, `awk` (no `bc` needed). The role used must allow `cloudwatch:ListMetrics`, `cloudwatch:GetMetricStatistics` and `pricing:GetProducts` (already granted by the `iam_role` module in this project).

Usage:

```bash
./bedrock-cost-report.sh
```

If a model's price isn't found automatically, the script asks for it interactively (USD per 1M tokens, check current pricing at [aws.amazon.com/bedrock/pricing](https://aws.amazon.com/bedrock/pricing/)). `.pricing_cache.json` is gitignored — review/update it manually whenever AWS pricing changes.

## Security

- Access to Bedrock is done via **assume-role**: the IAM User has no direct permissions on Bedrock, only permission to assume the dedicated role.
- The role's trust policy restricts who can assume it to the dedicated user itself.
- The permission boundary (when enabled) ensures the role can never exceed the Bedrock scope, even with additional policies attached in the future.
- Never commit `terraform.tfvars`, `*.tfstate` files, or credentials — already covered by `.gitignore`.

## Consuming the resources: client setup

After `terraform apply`, use the generated credentials and role to configure local access to Bedrock.

### 1. AWS CLI (`~/.aws`)

Get the sensitive Terraform outputs:

```bash
terraform output -raw bedrock_access_key_id
terraform output -raw bedrock_secret_access_key
terraform output -raw bedrock_role_arn
```

Configure a base profile with the dedicated IAM User's Access Key (`~/.aws/credentials`):

```ini
[bedrock]
aws_access_key_id     = <bedrock_access_key_id>
aws_secret_access_key = <bedrock_secret_access_key>
```

And a profile that assumes the role via `source_profile` (`~/.aws/config`):

```ini
[profile bedrock]
region          = us-east-1
output          = json
role_arn        = <bedrock_role_arn>
source_profile  = bedrock
```

Validate the assume-role:

```bash
aws sts get-caller-identity --profile bedrock
aws bedrock list-foundation-models --profile bedrock --region us-east-1
```

### 2. Claude Code pointing to Bedrock (`~/.claude`)

Install/update Claude Code to the version pinned by the project:

```bash
npm install -g @anthropic-ai/claude-code@2.1.92
```

Configure `~/.claude/settings.json` to use Bedrock with the profile created above:

```json
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_PROFILE": "bedrock",
    "AWS_REGION": "us-east-1"
  },
  "model": "us.anthropic.claude-sonnet-5"
}
```

- `CLAUDE_CODE_USE_BEDROCK=1` makes Claude Code call Bedrock instead of the public Anthropic API.
- `AWS_PROFILE` must point to the `bedrock` profile (the one that does assume-role), not to the profile with the IAM User's static credentials.
- The model in `model` must be a Bedrock inference profile ID (e.g., `us.anthropic.claude-sonnet-5`), compatible with what the `iam_role` module's `InvokeBedrockModels` policy authorizes.

Verify the installation and integration:

```bash
claude --version
claude "respond only 'ok' if Bedrock is accessible"
```

If the call fails due to permission, check whether the role in `bedrock_role_arn` already has access enabled to the desired model in the [Bedrock console (Model access)](https://console.aws.amazon.com/bedrock/) — the Terraform policy grants `InvokeModel`, but the model subscription/enablement itself is done separately by AWS.
