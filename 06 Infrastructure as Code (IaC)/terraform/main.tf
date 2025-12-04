module "vpc" {
  source = "./modules/vpc"

  aws_region = var.aws_region
}

module "eks" {
  source = "./modules/eks"

  cluster_name = var.cluster_name
  subnet_ids   = module.vpc.private_subnets
  vpc_id       = module.vpc.vpc_id
}

module "node_group" {
  source = "./modules/node_group"

  cluster_name = module.eks.cluster_name
  subnet_ids   = module.vpc.private_subnets
}
