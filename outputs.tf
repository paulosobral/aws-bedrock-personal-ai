# Outputs do projeto

# IAM Role Outputs
output "bedrock_role_arn" {
  description = "ARN da IAM Role para Bedrock"
  value       = module.iam_role.role_arn
}

output "bedrock_role_name" {
  description = "Nome da IAM Role para Bedrock"
  value       = module.iam_role.role_name
}

output "bedrock_user_arn" {
  description = "ARN do IAM User dedicado para Bedrock"
  value       = module.iam_role.user_arn
}

output "bedrock_user_name" {
  description = "Nome do IAM User dedicado para Bedrock"
  value       = module.iam_role.user_name
}

output "bedrock_access_key_id" {
  description = "Access Key ID do IAM User"
  value       = module.iam_role.access_key_id
  sensitive   = true
}

output "bedrock_secret_access_key" {
  description = "Secret Access Key do IAM User"
  value       = module.iam_role.secret_access_key
  sensitive   = true
}

output "permission_boundary_arn" {
  description = "ARN da permission boundary (se criada)"
  value       = module.iam_role.permission_boundary_arn
}

output "cloudtrail_arn" {
  description = "ARN do CloudTrail (se habilitado)"
  value       = module.iam_role.cloudtrail_arn
}

# Cost Alarm Outputs
output "sns_topic_arn" {
  description = "ARN do tópico SNS para alertas de custo"
  value       = module.cost_alarm.sns_topic_arn
}

output "sns_topic_name" {
  description = "Nome do tópico SNS"
  value       = module.cost_alarm.sns_topic_name
}

output "budget_arn" {
  description = "ARN do orçamento AWS Budgets"
  value       = module.cost_alarm.budget_arn
}

output "budget_name" {
  description = "Nome do orçamento"
  value       = module.cost_alarm.budget_name
}

output "token_alarm_name" {
  description = "Nome do alarme de tokens (se habilitado)"
  value       = module.cost_alarm.token_alarm_name
}

output "invocation_alarm_name" {
  description = "Nome do alarme de chamadas (se habilitado)"
  value       = module.cost_alarm.invocation_alarm_name
}

output "cost_alarm_name" {
  description = "Nome do alarme de custo (se habilitado)"
  value       = module.cost_alarm.cost_alarm_name
}
