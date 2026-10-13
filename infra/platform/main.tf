locals {
  name = var.project_name
  vpc_id = data.terraform_remote_state.bootstrap.outputs.vpc_id
  private_subnets = data.terraform_remote_state.bootstrap.outputs.private_subnet_ids
  public_subnets = data.terraform_remote_state.bootstrap.outputs.public_subnet_ids
  tags = { Project = local.name, ManagedBy = "Terraform", Environment = "hackathon" }
}
resource "aws_ecr_repository" "app" {
  name = "${local.name}-frontend"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = local.tags
}
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({ rules = [{ rulePriority = 1, description = "Keep latest 30 tagged images", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }, action = { type = "expire" } }] })
}
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"
  cluster_name = "${local.name}-eks"
  cluster_version = var.cluster_version
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true
  vpc_id = local.vpc_id
  subnet_ids = local.private_subnets
  control_plane_subnet_ids = local.private_subnets
  enable_cluster_creator_admin_permissions = true
  eks_managed_node_groups = {
    default = {
      name = "${local.name}-workers"
      instance_types = ["t3.medium"]
      min_size = 2
      max_size = 3
      desired_size = 2
      capacity_type = "ON_DEMAND"
    }
  }
  tags = local.tags
}
resource "aws_eks_access_entry" "runner" {
  cluster_name = module.eks.cluster_name
  principal_arn = data.terraform_remote_state.bootstrap.outputs.runner_role_arn
  type = "STANDARD"
}
resource "aws_eks_access_policy_association" "runner_admin" {
  cluster_name = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.runner.principal_arn
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
resource "helm_release" "monitoring" {
  name = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  version = "69.8.2"
  namespace = "monitoring"
  create_namespace = true
  values = [file("${path.module}/../../monitoring/values.yaml")]
  timeout = 900
  depends_on = [module.eks, aws_eks_access_policy_association.runner_admin]
}
resource "kubernetes_namespace" "app" {
  metadata { name = var.app_namespace }
  depends_on = [module.eks, aws_eks_access_policy_association.runner_admin]
}
