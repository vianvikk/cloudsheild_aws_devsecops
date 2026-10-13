output "cluster_name" { value = module.eks.cluster_name }
output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
output "ecr_repository_name" { value = aws_ecr_repository.app.name }
output "aws_account_id" { value = data.aws_caller_identity.current.account_id }
output "region" { value = var.aws_region }
