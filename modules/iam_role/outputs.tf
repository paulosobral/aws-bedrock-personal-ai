# Outputs do módulo IAM Role

output "role_arn" {
  description = "ARN da IAM Role criada"
  value       = aws_iam_role.bedrock_role.arn
}

output "role_name" {
  description = "Nome da IAM Role criada"
  value       = aws_iam_role.bedrock_role.name
}

output "user_arn" {
  description = "ARN do IAM User dedicado"
  value       = aws_iam_user.bedrock_user.arn
}

output "user_name" {
  description = "Nome do IAM User dedicado"
  value       = aws_iam_user.bedrock_user.name
}

output "access_key_id" {
  description = "Access Key ID do IAM User"
  value       = aws_iam_access_key.bedrock_user_key.id
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret Access Key do IAM User"
  value       = aws_iam_access_key.bedrock_user_key.secret
  sensitive   = true
}

output "permission_boundary_arn" {
  description = "ARN da permission boundary (se criada)"
  value       = var.create_permission_boundary ? aws_iam_policy.bedrock_permission_boundary[0].arn : null
}

output "cloudtrail_arn" {
  description = "ARN do CloudTrail (se habilitado)"
  value       = var.enable_cloudtrail ? aws_cloudtrail.bedrock_audit[0].arn : null
}
