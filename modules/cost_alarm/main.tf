# Módulo Cost Alarm para monitoramento de custos Bedrock
# Cria alarmes CloudWatch e tópico SNS para notificações

# Tópico SNS para notificações de custo
resource "aws_sns_topic" "cost_alerts" {
  name         = var.sns_topic_name
  display_name = "Bedrock Cost Alerts - personal"
  tags = merge(
    var.tags,
    {
      Name = var.sns_topic_name
    }
  )
}

# Assinatura de e-mail para personal
resource "aws_sns_topic_subscription" "email_subscription" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Budget AWS para monitoramento de custos Bedrock
resource "aws_budgets_budget" "bedrock_budget" {
  name              = var.budget_name
  budget_type       = "COST"
  limit_amount      = var.budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_end   = "2087-06-15_00:00"
  time_period_start = "2025-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.notification_threshold
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_email != "" ? [var.notification_email] : []
  }

  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock"]
  }

  tags = var.tags
}

# CloudWatch Metric Alarm para tokens consumidos
resource "aws_cloudwatch_metric_alarm" "token_consumption" {
  count               = var.enable_token_alarm ? 1 : 0
  alarm_name          = "${var.alarm_prefix}-token-consumption"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "TokenCount"
  namespace           = "AWS/Bedrock"
  period              = var.period
  statistic           = "Sum"
  threshold           = var.token_threshold
  alarm_description   = "Alarme para consumo de tokens Bedrock - usuário personal"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  ok_actions          = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    ModelId = "anthropic.claude-3-haiku-20240307-v1:0"
  }

  tags = var.tags
}

# CloudWatch Metric Alarm para chamadas ao modelo
resource "aws_cloudwatch_metric_alarm" "invocation_count" {
  count               = var.enable_invocation_alarm ? 1 : 0
  alarm_name          = "${var.alarm_prefix}-invocation-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "Invocations"
  namespace           = "AWS/Bedrock"
  period              = var.period
  statistic           = "Sum"
  threshold           = var.invocation_threshold
  alarm_description   = "Alarme para número de chamadas ao modelo Bedrock - usuário personal"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  ok_actions          = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    ModelId = "anthropic.claude-3-haiku-20240307-v1:0"
  }

  tags = var.tags
}

# CloudWatch Metric Alarm para custo acumulado
resource "aws_cloudwatch_metric_alarm" "cost_accumulated" {
  count               = var.enable_cost_alarm ? 1 : 0
  alarm_name          = "${var.alarm_prefix}-cost-accumulated"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "EstimatedCost"
  namespace           = "AWS/Billing"
  period              = var.period
  statistic           = "Maximum"
  threshold           = var.cost_threshold
  alarm_description   = "Alarme para custo acumulado Bedrock - usuário personal"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  ok_actions          = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    Currency = "USD"
  }

  tags = var.tags
}
