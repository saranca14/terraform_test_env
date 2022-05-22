module "vpc" {
  source = "./modules/mm-infra"
}

output "vpc_id" {
  #value = aws_vpc.mm_vpc.id
  value = "${module.vpc.vpcid}"
}

output "app_name" {
  #value = aws_vpc.mm_vpc.id
  value = "${module.vpc.elastic_beanstalk_app}"
}

output "app_url" {
  #value = aws_vpc.mm_vpc.id
  value = "${module.vpc.elastic_beanstalk_url}"
}