# AWS Bedrock Personal AI

Infraestrutura como código (Terraform) para provisionar acesso seguro e monitorado ao Amazon Bedrock, com IAM restrito a least-privilege e alarmes de custo/consumo.

## O que este projeto provisiona

### Módulo `iam_role`
- **IAM User dedicado** (`/bedrock/`) exclusivo para uso do Bedrock, com Access Key própria.
- **IAM Role** que só pode ser assumida pelo próprio user dedicado (trust policy restrita por `aws:PrincipalArn`).
- **Política least-privilege** anexada à role: permite `bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`, `bedrock:ListFoundationModels`, `bedrock:ListInferenceProfiles` e ações mínimas de AWS Marketplace (necessárias para assinar modelos de terceiros no Bedrock); nega qualquer ação `iam:*` além de `PassRole`.
- **Permission Boundary** opcional que limita a role estritamente às ações do Bedrock, mesmo que políticas futuras sejam anexadas por engano.
- **CloudTrail** multi-região opcional para auditoria de todas as chamadas ao Bedrock.

### Módulo `cost_alarm`
- **Tópico SNS** com assinatura por e-mail para alertas.
- **AWS Budget** mensal filtrado pelo serviço "Amazon Bedrock", com notificação ao atingir um percentual do limite.
- **Alarmes do CloudWatch** (habilitáveis individualmente):
  - Consumo de tokens (`AWS/Bedrock` `TokenCount`)
  - Número de invocações (`AWS/Bedrock` `Invocations`)
  - Custo acumulado (`AWS/Billing` `EstimatedCost`)

## Estrutura

```
.
├── main.tf                  # Provider AWS, backend S3 e chamada dos módulos
├── variables.tf             # Variáveis do projeto (com defaults)
├── outputs.tf                # Outputs consolidados dos módulos
├── modules/
│   ├── iam_role/             # User, Role, políticas, boundary e CloudTrail
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── cost_alarm/           # SNS, Budgets e alarmes CloudWatch
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── .gitignore
```

## Pré-requisitos

### Ferramentas

| Ferramenta | Versão | Uso no projeto | Instalação |
|---|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform) | `>= 1.6` | Provisionar toda a infra (IAM, SNS, Budgets, CloudWatch, CloudTrail) | [Download](https://developer.hashicorp.com/terraform/install) |
| [AWS CLI](https://aws.amazon.com/cli/) | `v2` | Autenticação (`aws configure`), validação do assume-role e chamadas ao Bedrock | [Guia de instalação](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| [Node.js](https://nodejs.org/) | `>= 18` | Necessário para instalar o Claude Code via `npm` | [Download](https://nodejs.org/) |
| [Claude Code](https://www.npmjs.com/package/@anthropic-ai/claude-code) | `2.1.92` | Cliente que consome o Bedrock (opcional, ver seção [Consumindo os recursos](#consumindo-os-recursos-setup-do-cliente)) | `npm install -g @anthropic-ai/claude-code@2.1.92` |
| Provider AWS (Terraform) | `~> 5.0` | Instalado automaticamente pelo `terraform init` | — |

### Conta e acesso AWS

- Conta AWS com credenciais configuradas (`aws configure` ou variáveis de ambiente `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`) e permissão para criar recursos IAM, SNS, Budgets, CloudWatch e (opcionalmente) CloudTrail.
- Bucket S3 já existente para o backend remoto do Terraform (`terraform-state-bedrock-psobral89`) e, se `enable_cloudtrail = true`, um bucket S3 para os logs do CloudTrail.
- Acesso liberado aos modelos desejados no [console do Bedrock (Model access)](https://console.aws.amazon.com/bedrock/) — isso é feito manualmente pela AWS e não é provisionado pelo Terraform.

## Uso

```bash
# Inicializar o backend e os providers
terraform init

# Ver o plano de execução
terraform plan

# Aplicar as mudanças
terraform apply
```

Para destruir os recursos:

```bash
terraform destroy
```

## Variáveis principais

Todas as variáveis possuem valores padrão em `variables.tf`. As mais relevantes para customizar:

| Variável | Descrição | Default |
|---|---|---|
| `bedrock_role_name` | Nome da IAM Role | `bedrock-user-psobral89-role` |
| `notification_email` | E-mail para alertas de custo | `paulo.sobral@outlook.com.br` |
| `budget_limit` | Limite mensal do orçamento (USD) | `50.0` |
| `notification_threshold` | % do orçamento para notificar | `80.0` |
| `enable_cloudtrail` | Habilita auditoria via CloudTrail | `true` |
| `cloudtrail_bucket_name` | Bucket S3 para logs do CloudTrail | `cloudtrail-logs-bedrock-psobral89` |
| `enable_token_alarm` / `token_threshold` | Alarme de tokens consumidos | `true` / `100000` |
| `enable_invocation_alarm` / `invocation_threshold` | Alarme de nº de chamadas | `true` / `1000` |
| `enable_cost_alarm` / `cost_threshold` | Alarme de custo acumulado (USD) | `true` / `10.0` |

Para sobrescrever, crie um `terraform.tfvars` (ignorado pelo `.gitignore`) ou passe `-var` na linha de comando.

## Outputs

Após o `apply`, os principais outputs disponíveis incluem `bedrock_role_arn`, `bedrock_user_arn`, `sns_topic_arn`, `budget_arn` e os nomes dos alarmes criados. As credenciais (`bedrock_access_key_id` e `bedrock_secret_access_key`) são marcadas como `sensitive` — use `terraform output -raw <nome>` para exibi-las.

## Segurança

- O acesso ao Bedrock é feito via **assume-role**: o IAM User não tem permissões diretas sobre o Bedrock, apenas a permissão de assumir a role dedicada.
- A trust policy da role restringe quem pode assumi-la ao próprio user dedicado.
- A permission boundary (quando habilitada) garante que a role nunca poderá exceder o escopo Bedrock, mesmo com políticas adicionadas futuramente.
- Nunca commite `terraform.tfvars`, arquivos `*.tfstate` ou credenciais — já cobertos pelo `.gitignore`.

## Consumindo os recursos: setup do cliente

Depois do `terraform apply`, use as credenciais e a role gerados para configurar o acesso local ao Bedrock.

### 1. AWS CLI (`~/.aws`)

Pegue as saídas sensíveis do Terraform:

```bash
terraform output -raw bedrock_access_key_id
terraform output -raw bedrock_secret_access_key
terraform output -raw bedrock_role_arn
```

Configure um profile de base com o Access Key do IAM User dedicado (`~/.aws/credentials`):

```ini
[bedrock]
aws_access_key_id     = <bedrock_access_key_id>
aws_secret_access_key = <bedrock_secret_access_key>
```

E um profile que assume a role via `source_profile` (`~/.aws/config`):

```ini
[profile bedrock]
region          = us-east-1
output          = json
role_arn        = <bedrock_role_arn>
source_profile  = bedrock
```

Valide o assume-role:

```bash
aws sts get-caller-identity --profile bedrock
aws bedrock list-foundation-models --profile bedrock --region us-east-1
```

### 2. Claude Code apontando para o Bedrock (`~/.claude`)

Instale/atualize o Claude Code na versão fixada pelo projeto:

```bash
npm install -g @anthropic-ai/claude-code@2.1.92
```

Configure `~/.claude/settings.json` para usar o Bedrock com o profile criado acima:

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

- `CLAUDE_CODE_USE_BEDROCK=1` faz o Claude Code chamar o Bedrock em vez da API pública da Anthropic.
- `AWS_PROFILE` deve apontar para o profile `bedrock` (o que faz assume-role), não para o profile com as credenciais estáticas do IAM User.
- O modelo em `model` precisa ser um ID de inference profile do Bedrock (ex.: `us.anthropic.claude-sonnet-5`), compatível com o que a policy `InvokeBedrockModels` do módulo `iam_role` autoriza.

Verifique a instalação e a integração:

```bash
claude --version
claude "responda apenas 'ok' se o Bedrock estiver acessível"
```

Se a chamada falhar por permissão, confira se a role em `bedrock_role_arn` já tem acesso liberado ao modelo desejado no [console do Bedrock (Model access)](https://console.aws.amazon.com/bedrock/) — a policy do Terraform libera `InvokeModel`, mas a assinatura/habilitação do modelo em si é feita separadamente pela AWS.
