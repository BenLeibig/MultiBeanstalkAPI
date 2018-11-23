#--------------------------------------------------------------
# This module creates a docker/beanstalk instance with everything required for deployment.
# One environment/stage is created for each stage listed in the environments list
#--------------------------------------------------------------

variable "app_name" {}
variable "app_description" {}
variable "environments" {
  default = "dev"
} # , deliminated list of all environments to create eg "dev,stage,prod"
variable "max_nodes" {
  default = "4"
}
variable "min_nodes" {
  default = "2"
}
variable "instance_size" {
  default = "t2.micro"
}
variable "healthcheck_url" {
  default = "/_health"
}
variable "ec2_instance_profile_name" {
  default = "eb-beanstalk-ec2-user"
}
variable "private_subnet_ids" {
  description = "Private subnets passed in from main.tf"
}
variable "public_subnet_ids" {
  description = "public subnets passed in from main.tf"
}
variable "vpc_id" {
  description = "VPC id passed from main"

}

resource "aws_ecr_repository" "eb_container_repository" {
  name = "${var.app_name}_ecr"
}


resource "aws_elastic_beanstalk_application" "eb_beanstalk_application" {
  name = "${var.app_name}"
  description = "${var.app_description}"
}


resource "aws_elastic_beanstalk_environment" "eb_beanstalk_application_environment" {
  name                = "${var.app_name}-${element(split(",", var.environments), count.index)}"
  application         = "${aws_elastic_beanstalk_application.eb_beanstalk_application.name}"
  solution_stack_name = "64bit Amazon Linux 2018.03 v2.11.5 running Multi-container Docker 18.06.1-ce"  ###  This should be sometimes updated based on: https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.mcdocker
  tier                = "WebServer"
  count               = "${length(split(",", var.environments))}"

  # instance type
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "${var.instance_size}"
  }

  # There are a LOT of settings, see here for the basic list:
  # https://is.gd/vfB51g

  # You can set the environment type, single or LoadBalanced
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
  # which vpc to use
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "${var.vpc_id}"
  }

  setting {
    namespace = "aws:ec2:vpc"                          ### this setting is the subnets for the worker instances launched by ELB
    name      = "Subnets"
    value     = "${var.private_subnet_ids}"
  }
  setting {
    namespace = "aws:ec2:vpc"                         #### the next two settings place the loadbalancer on the public submet
    name      = "ELBSubnets"
    value     = "${var.public_subnet_ids}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "Public"
  }
  # Are the load balancers multizone?
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "CrossZone"
    value     = "true"
  }
  # Enable connection draining.
  setting {
    namespace = "aws:elb:policies"
    name      = "ConnectionDrainingEnabled"
    value     = "true"
  }
  # require at least 2 nodes for HA
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "${var.min_nodes}"
  }
  # Healthcheck location
  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "Application Healthcheck URL"
    value     = "${var.healthcheck_url}"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "${var.max_nodes}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "${var.ec2_instance_profile_name}"
  }
}
