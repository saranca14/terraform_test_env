# Filter out  zones
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "group-name"
    values = ["us-east-1"]
  }
}
data "aws_region" "current" {}

# Main VPC resource
resource "aws_vpc" "mm_vpc" {
  cidr_block                       = var.vpc_cidr
  instance_tenancy                 = var.vpc_instance_tenancy
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = merge(
    { "Name" = "${var.main_project_tag}-vpc" },
    { "Project" = var.main_project_tag },
    var.vpc_tags
  )
}

## Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mm_vpc.id

  tags = merge(
    { "Name" = "${var.main_project_tag}-igw" },
    { "Project" = var.main_project_tag },
    var.vpc_tags
  )
}

## Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mm_vpc.id
  tags = merge(
    { "Name" = "${var.main_project_tag}-public-rtb" },
    { "Project" = var.main_project_tag },
    var.vpc_tags
  )
}

## Public routes
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

## Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.mm_vpc.id
  tags = merge(
    { "Name" = "${var.main_project_tag}-private-rtb" },
    { "Project" = var.main_project_tag },
    var.vpc_tags
  )
}

## Public Subnets
resource "aws_subnet" "public" {
  count = var.vpc_public_subnet_count

  vpc_id                  = aws_vpc.mm_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.mm_vpc.cidr_block, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  ipv6_cidr_block                 = cidrsubnet(aws_vpc.mm_vpc.ipv6_cidr_block, 8, count.index)
  assign_ipv6_address_on_creation = true

  tags = merge(
    { "Name" = "${var.main_project_tag}-public-${data.aws_availability_zones.available.names[count.index]}" },
    { "Project" = var.main_project_tag },
    var.vpc_tags
  )
}

## Private Subnets
resource "aws_subnet" "private" {
  count = var.vpc_private_subnet_count

  vpc_id = aws_vpc.mm_vpc.id

  // Increment the netnum by the number of public subnets to avoid overlap
  cidr_block        = cidrsubnet(aws_vpc.mm_vpc.cidr_block, 4, count.index + var.vpc_public_subnet_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    { "Name" = "${var.main_project_tag}-private-${data.aws_availability_zones.available.names[count.index]}" },
    { "Project" = var.main_project_tag },
    var.vpc_tags
  )
}

## Public Subnet Route Associations
resource "aws_route_table_association" "public" {
  count = var.vpc_public_subnet_count

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

## Private Subnet Route Associations
resource "aws_route_table_association" "private" {
  count = var.vpc_private_subnet_count

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

#Elastic Beanstalk block:

resource "aws_elastic_beanstalk_application" "application" {
  name        = "mutual-mobile-demo-app"
}
resource "aws_elastic_beanstalk_environment" "environment" {
  name                = "mutual-mobile-demo-app-environment"
  application         = aws_elastic_beanstalk_application.application.name
  solution_stack_name = "64bit Amazon Linux 2 v3.3.13 running Python 3.8"

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.mm_vpc.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "Subnets"
    #value = toset(aws_subnet.public.*.id)
    #value = "${join(",", aws_subnet.public.*.id)}"
    value = "${join(",", aws_subnet.public.*.id)}"
  }
  setting {
      namespace = "aws:autoscaling:launchconfiguration"
      name = "IamInstanceProfile"
      value = "aws-elasticbeanstalk-ec2-role"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.micro"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "AssociatePublicIpAddress"
    value = "true"
  }

  setting {
    name = "ConfigDocument"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    value = "{\"Version\":1,\"Rules\":{\"Environment\":{\"Application\":{\"ApplicationRequests4xx\":{\"Enabled\":false}}}}}"
  }

   setting {
    name = "ConfigDocument"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    value = "{\"Version\":1,\"Rules\":{\"Environment\":{\"ELB\":{\"ELBRequests4xx\":{\"Enabled\":false}}}}}"
   }
}

output "vpcid" {
  value = aws_vpc.mm_vpc.id
}

output "elastic_beanstalk_app" {
  value = aws_elastic_beanstalk_application.application.name
}

output "elastic_beanstalk_url" {
  value = aws_elastic_beanstalk_environment.environment.endpoint_url
}