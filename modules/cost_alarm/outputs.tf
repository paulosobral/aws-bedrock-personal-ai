# Outputs do módulo Cost Alarm

output "sns_topic_arn" {
  description = "ARN do tópico SNS para alertas de custo"
  value       = aws_sns_topic.cost_alerts.arn
}

output "sns_topic_name" {
  description = "Nome do tópico SNS"
  value       = aws_sns_topic.cost_alerts.name
}

output "budget_arn" {
  description = "ARN do orçamento AWS Budgets"
  value       = aws_budgets_budget.bedrock_budget.arn
}

output "budget_name" {
  description = "Nome do orçamento"
  value       = aws_budgets_budget.bedrock_budget.name
}

output "token_alarm_name" {
  description = "Nome do alarme de tokens (se habilitado)"
  value       = var.enable_token_alarm ? aws_cloudwatch_metric_alarm.token_consumption[0].alarm_name : null
}

output "invocation_alarm_name" {
  description = "Nome do alarme de chamadas (se habilitado)"
  value       = var.enable_invocation_alarm ? aws_cloudwatch_metric_alarm.invocation_count[0].alarm_name : null
}

output "cost_alarm_name" {
  description = "Nome do alarme de custo (se habilitado)"
  value       = var.enable_cost_alarm ? aws_cloudwatch_metric_alarm.cost_accumulated[0].alarm_name : null
}
