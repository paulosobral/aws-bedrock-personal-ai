# Variáveis de configuração do projeto

variable "default_tags" {
  description = "Tags obrigatórias para governança (aplicadas a todos os recursos)"
  type        = map(string)
  default = {
    Owner       = "personal"
    Environment = "Dev"
    Service     = "Bedrock"
    ManagedBy   = "Terraform"
  }
}

# Variáveis IAM Role
variable "bedrock_role_name" {
  description = "Nome da IAM Role para Bedrock"
  type        = string
  default     = "bedrock-user-personal-role"
}

variable "permission_boundary_arn" {
  description = "ARN opcional de uma permission boundary existente"
  type        = string
  default     = null
}

variable "create_permission_boundary" {
  description = "Criar permission boundary se true"
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "Habilitar CloudTrail para auditoria de chamadas Bedrock"
  type        = bool
  default     = true
}

variable "cloudtrail_bucket_name" {
  description = "Nome do bucket S3 para logs do CloudTrail - OBRIGATÓRIO se enable_cloudtrail=true"
  type        = string
  default     = "cloudtrail-logs-bedrock-personal"
}

# Variáveis Cost Alarm
variable "sns_topic_name" {
  description = "Nome do tópico SNS para alertas de custo"
  type        = string
  default     = "bedrock-cost-alerts-personal"
}

variable "notification_email" {
  description = "E-mail para notificações de custo (personal) - OBRIGATÓRIO"
  type        = string
}

variable "budget_name" {
  description = "Nome do orçamento AWS Budgets"
  type        = string
  default     = "bedrock-budget-personal"
}

variable "budget_limit" {
  description = "Limite mensal do orçamento em USD"
  type        = number
  default     = 10.0
}

variable "notification_threshold" {
  description = "Porcentagem do orçamento para enviar notificação (ex: 80.0 = 80%)"
  type        = number
  default     = 80.0
}

variable "alarm_prefix" {
  description = "Prefixo para nomes dos alarmes CloudWatch"
  type        = string
  default     = "bedrock-personal"
}

variable "alarm_period" {
  description = "Período de avaliação em segundos (ex: 3600 = 1 hora)"
  type        = number
  default     = 3600
}

variable "evaluation_periods" {
  description = "Número de períodos para avaliação"
  type        = number
  default     = 1
}

variable "enable_token_alarm" {
  description = "Habilitar alarme de consumo de tokens"
  type        = bool
  default     = true
}

variable "token_threshold" {
  description = "Limite para alarme de tokens consumidos"
  type        = number
  default     = 100000
}

variable "enable_invocation_alarm" {
  description = "Habilitar alarme de chamadas ao modelo"
  type        = bool
  default     = true
}

variable "invocation_threshold" {
  description = "Limite para alarme de chamadas ao modelo"
  type        = number
  default     = 1000
}

variable "enable_cost_alarm" {
  description = "Habilitar alarme de custo acumulado"
  type        = bool
  default     = true
}

variable "cost_threshold" {
  description = "Limite para alarme de custo acumulado em USD"
  type        = number
  default     = 10.0
}
