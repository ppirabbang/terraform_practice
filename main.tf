# 1. provider 설정
provider "aws"{
  region = var.region
}

data "aws_availability_zones" "available"{
  state = "available"
}

module "db" {
  source = "./modules/db"
  name_prefix = var.name_prefix
  db_subnet_ids = module.vpc.db_subnet_ids
  security_group_db = module.vpc.security_group_db
}
module "ec2"{
  source = "./modules/ec2"
  name_prefix = var.name_prefix
  security_group_app = module.vpc.security_group_app
  private_subnet_ids = module.vpc.private_subnet_ids
  lb_target_group_prod_arn = module.alb.lb_target_group_prod_arn
}
module "alb"{
  source = "./modules/alb"
  name_prefix = var.name_prefix
  security_group_alb = module.vpc.security_group_alb
  public_subnets_ids = module.vpc.public_subnet_ids
  vpc_id = module.vpc.vpc_id
}
module "vpc" {
  source = "./modules/vpc"
  name_prefix     = var.name_prefix
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  db_subnets      = var.db_subnets
}

module "s3" {
  source = "./modules/s3-buckets"
  name_prefix = var.name_prefix
}

module "cloudtrail" {
  source = "./modules/cloudtrail"
  name_prefix = var.name_prefix
  audit_bucket_policy_id = module.s3.audit_bucket_policy_id
  audit_bucket = module.s3.audit_bucket
  # 자식 모듈의 variable에 선언되어 있고 자식에 전달해줄 값
}