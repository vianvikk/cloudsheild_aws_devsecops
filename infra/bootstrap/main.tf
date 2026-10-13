data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current" {}
data "aws_ami" "al2023" {
  most_recent = true
  owners = ["amazon"]
  filter { name = "name"
  values = ["al2023-ami-2023.*-x86_64"] }
  filter { name = "architecture"
  values = ["x86_64"] }
}
locals {
  name = var.project_name
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  common_tags = { Project = local.name, ManagedBy = "Terraform", Environment = "hackathon" }
}
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, { Name = "${local.name}-igw" })
}
resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, { Name = "${local.name}-public-${count.index + 1}", "kubernetes.io/role/elb" = "1" })
}
resource "aws_subnet" "private" {
  count = 2
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags = merge(local.common_tags, { Name = "${local.name}-private-${count.index + 1}", "kubernetes.io/role/internal-elb" = "1" })
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id }
  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" { domain = "vpc"
  tags = local.common_tags }
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public[0].id
  depends_on = [aws_internet_gateway.main]
  tags = merge(local.common_tags, { Name = "${local.name}-nat" })
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id }
  tags = merge(local.common_tags, { Name = "${local.name}-private-rt" })
}
resource "aws_route_table_association" "private" {
  count = 2
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "runner" {
  name = "${local.name}-runner-sg"
  description = "Runner outbound access; no public admin ports by default"
  vpc_id = aws_vpc.main.id
  ingress {
    description = "Optional SonarQube UI - restrict to admin CIDR"
    from_port = 9000
  to_port = 9000
  protocol = "tcp"
  cidr_blocks = [var.allowed_admin_cidr]
  }
  ingress {
    description = "Optional host Grafana UI - restrict to admin CIDR"
    from_port = 3000
  to_port = 3000
  protocol = "tcp"
  cidr_blocks = [var.allowed_admin_cidr]
  }
  egress { from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"] }
  tags = local.common_tags
}
resource "aws_iam_role" "runner" {
  name = "${local.name}-runner-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags = local.common_tags
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "runner" {
  name = "${local.name}-runner-platform-management"
  role = aws_iam_role.runner.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.runner_pat_secret_name}*" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"], Resource = ["arn:aws:s3:::${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}", "arn:aws:s3:::${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}/*"] },
      { Effect = "Allow", Action = ["ecr:*", "eks:*", "ec2:*", "iam:*", "elasticloadbalancing:*", "autoscaling:*", "cloudformation:*", "ssm:GetParameter", "ssm:GetParameters", "sts:GetCallerIdentity"], Resource = "*" }
    ]
  })
}
resource "aws_iam_instance_profile" "runner" { name = "${local.name}-runner-profile"
  role = aws_iam_role.runner.name }
resource "aws_instance" "runner" {
  ami = data.aws_ami.al2023.id
  instance_type = var.runner_instance_type
  subnet_id = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.runner.id]
  iam_instance_profile = aws_iam_instance_profile.runner.name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region = var.aws_region
    secret_name = var.runner_pat_secret_name
    github_owner = var.github_owner
    github_repo = var.github_repo
    runner_name = "${local.name}-runner"
  })
  user_data_replace_on_change = true
  root_block_device { volume_size = 40
  volume_type = "gp3"
  encrypted = true }
  metadata_options { http_tokens = "required"
  http_endpoint = "enabled" }
  tags = merge(local.common_tags, { Name = "${local.name}-runner" })
}
