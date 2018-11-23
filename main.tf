# Configure AWS Credentials & Region

provider "aws" {
  profile = "${var.profile}"
  region  = "${var.region}"
}

module "network" {
  source ="./modules/network"
  name = "${var.network_name}"
  vpc_cidr = "10.0.0.0/16"
  azs = "${var.azs}"
  region = "eu-central-1"
  private_subnets="10.0.1.0/24,10.0.2.0/24,10.0.3.0/24"
  public_subnets="10.0.101.0/24,10.0.102.0/24,10.0.103.0/24"
}

data "terraform_remote_state" "bigbucket" {
  backend = "s3"
  config {
    bucket = "${var.s3["bucket"]}"
    key    = "${var.s3["key]}"
    region = "${var.region}"
    profile = "${var.profile}"
  }
}


### IAM Setup - Security settings for beanstalk are here
resource "aws_iam_instance_profile" "beanstalk_ec2" {
  name  = "beanstalk-ec2-user"
  role = "${aws_iam_role.beanstalk_ec2.name}"
}

resource "aws_iam_role" "beanstalk_ec2" {
  name = "beanstalk-ec2-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Beanstalk EC2 Policy
# Overriding default policy to give beanstalk permission to Read ECR
resource "aws_iam_role_policy" "beanstalk_ec2_policy" {
  name = "beanstalk_ec2_policy_with_ECR"
  role = "${aws_iam_role.beanstalk_ec2.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "cloudwatch:PutMetricData",
        "ds:CreateComputer",
        "ds:DescribeDirectories",
        "ec2:DescribeInstanceStatus",
        "logs:*",
        "ssm:*",
        "ec2messages:*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
##### End Security settings
## One S3 bucket for all beanstalk app deployment files to save clutter.
## for this reason the definition lives outside the module.
resource "aws_s3_bucket" "beanstalk_deploys" {
  bucket = "${var.deployment_s3_bucket}"
  force_destroy = "true"
}
#### One of these module blocks is needed for each beanstalk ap to be setup.

module "example-beanstalk" {
  ### the settings below should be changed for your application
  app_name = "example-api"
  app_description = "An example API"
  environments = "dev,test"
  max_nodes = "4"
  min_nodes = "2" ## Ensures H/A
  instance_size = "t2.micro"
  healthcheck_url = "/_health"
  ### the settings below are just required programatically and should not be changed
  source = "./modules/SimpleHABeanstalk"
  public_subnet_ids ="${module.network.public_subnet_ids}"
  private_subnet_ids ="${module.network.private_subnet_ids}"
  vpc_id = "${module.network.vpc_id}"
}
