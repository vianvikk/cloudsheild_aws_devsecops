output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "runner_instance_id" { value = aws_instance.runner.id }
output "runner_public_ip" { value = aws_instance.runner.public_ip }
output "runner_role_arn" { value = aws_iam_role.runner.arn }
output "state_bucket_name" { value = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}" }
