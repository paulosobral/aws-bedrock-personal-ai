# Variáveis do módulo IAM Role

variable "role_name" {
  description = "Nome da IAM Role para Bedrock"
  type        = string
  default     = "bedrock-user-psobral89-role"
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

variable "permission_boundary_arn" {
  description = "ARN opcional de uma permission boundary existente"
  type        = string
  default     = null
}

variable "create_permission_boundary" {
  description = "Criar permission boundary se true"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Habilitar CloudTrail para auditoria de chamadas Bedrock"
  type        = bool
  default     = true
}

variable "cloudtrail_bucket_name" {
  description = "Nome do bucket S3 para logs do CloudTrail"
  type        = string
  default     = ""
}
