# Variáveis do módulo Cost Alarm

variable "sns_topic_name" {
  description = "Nome do tópico SNS para alertas de custo"
  type        = string
  default     = "bedrock-cost-alerts-psobral89"
}

variable "notification_email" {
  description = "E-mail para notificações de custo (psobral89)"
  type        = string
  default     = ""
}

variable "budget_name" {
  description = "Nome do orçamento AWS Budgets"
  type        = string
  default     = "bedrock-budget-psobral89"
}

variable "budget_limit" {
  description = "Limite mensal do orçamento em USD"
  type        = number
  default     = 50.0
}

variable "notification_threshold" {
  description = "Porcentagem do orçamento para enviar notificação"
  type        = number
  default     = 80.0
}

variable "alarm_prefix" {
  description = "Prefixo para nomes dos alarmes CloudWatch"
  type        = string
  default     = "bedrock-psobral89"
}

variable "period" {
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

variable "tags" {
  description = "Tags obrigatórias para governança"
  type        = map(string)
  default = {
    Owner       = "psobral89"
    Environment = "Dev"
    Service     = "Bedrock"
  }
}
