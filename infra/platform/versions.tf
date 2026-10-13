terraform {
  required_version = ">= 1.10.0"
  required_providers = {
    aws = { source = "hashicorp/aws", version = "~> 5.80" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.35" }
    helm = { source = "hashicorp/helm", version = "~> 2.17" }
  }
  backend "s3" {}
}
provider "aws" { region = var.aws_region }
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = { bucket = var.state_bucket, key = "bootstrap/terraform.tfstate", region = var.aws_region, encrypt = true }
}
data "aws_caller_identity" "current" {}
data "aws_eks_cluster" "cluster" { name = module.eks.cluster_name }
data "aws_eks_cluster_auth" "cluster" { name = module.eks.cluster_name }
provider "kubernetes" {
  host = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token = data.aws_eks_cluster_auth.cluster.token
}
provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token = data.aws_eks_cluster_auth.cluster.token
  }
}
