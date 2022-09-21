provider "aws" {
  region = local.region
}

locals {
  name   = "bti-staging"
  region = "us-east-1"
  tags = {
    Owner       = "juyel"
    Environment = "dev"
  }
}

################################################################################
# Supporting Resources
################################################################################

resource "random_password" "master" {
  length = 10
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.99.0.0/18"

  azs              = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets   = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets  = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]

  tags = local.tags
}

################################################################################
# RDS Aurora Module
################################################################################

module "db" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name                  = local.name
  engine                = "aurora-mysql"
  engine_version        = "5.7.12"
  

  vpc_id                = module.vpc.vpc_id
  db_subnet_group_name  = module.vpc.database_subnet_group_name
  create_security_group = true
  allowed_cidr_blocks   = module.vpc.private_subnets_cidr_blocks

  replica_count                       = 2
  iam_database_authentication_enabled = true
  password                            = random_password.master.result
  create_random_password              = false

  apply_immediately   = true
  skip_final_snapshot = true

  db_parameter_group_name         = aws_db_parameter_group.aurora.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.id
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  tags = local.tags
}

resource "aws_db_parameter_group" "aurora" {
  name        = "${local.name}-aurora-db-57-parameter-group"
  family      = "aurora-mysql5.7"
  description = "${local.name}-aurora-db-57-parameter-group"
  tags        = local.tags
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${local.name}-aurora-57-cluster-parameter-group"
  family      = "aurora-mysql5.7"
  description = "${local.name}-aurora-57-cluster-parameter-group"
  tags        = local.tags
}