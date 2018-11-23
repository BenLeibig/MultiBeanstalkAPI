## this module should be used with a depends on for all SimpleHABeanstalk modules
variable "environments"{
  type = "list"
  description = "The environments to gateway for (use only lower case)"
  default = ["dev"]
}
variable "base_confdir"{
  description =  "The directory with all the NGINX conf segements with a trailing /"
}
variable "aws_profile"{
  description = "Working profile on local PC to push dockerfile to ECR"
}
variable "aws_region"{
  description = "Region of profile on local PC to push dockerfile to ECR"
}

variable "max_nodes" {
  default = "1"
}
variable "min_nodes" {
  default = "1"
}
variable "instance_size" {
  default = "t2.micro"
}
variable "ec2_instance_profile_name" {
  default = "eb-beanstalk-ec2-user"
}
variable "app_name"{
  default = "nginx-bs-proxy"
}
variable "instance_subnet_ids" {
  description = "Private subnets passed in from main.tf"
  type = "list"
}
variable "lb_subnet_ids" {
  description = "public subnets passed in from main.tf"
  type = "list"
}
variable "vpc_id" {
  description = "VPC id passed from main"
}


resource "aws_ecr_repository" "eb_container_repository" {
  name = "${var.app_name}"
}
/*
### Generate environment specifiic config file
data "template_file" "nginx-default-conf" {
  template = "${file("${path.module}/templates/default.conf.template")}"
  vars {
    environment = "${element(var.environments, count.index)}"
    hostname = "${element(aws_elastic_beanstalk_environment.NGINX.*.cname, count.index)}"
    port = "${var.port_number}"
  }
  count = "${length(var.environments)}"
}
###
resource local_file "defaultconf"
 {
  content     = "${element(data.template_file.nginx-default-conf.*.rendered, count.index)}"
  filename = "${path.root}/localfile/${var.app_name}/${element(var.environments, count.index)}/conf/default.conf"
  count = "${length(var.environments)}"
}
*/
resource "local_file" "Dockerrun_template"{
  content = <<EOF
  {
    "AWSEBDockerrunVersion": "1",
    "Image": {
      "Name": "<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/<NAME>:<VERSION>",
      "Update": "true"
    },
    "Ports": [
      {
        "ContainerPort": "<PORT>"
      }
    ]
  }
EOF
  filename = "${path.root}/localfile/${var.app_name}/${element(var.environments, count.index)}/Dockerrun.aws.json.template"
  count = "${length(var.environments)}"
}

resource "local_file" "dockerfile" {
  content     = <<EOF
  FROM amazonlinux
  RUN yum install -y nginx zip curl
  RUN echo "daemon off;" >> /etc/nginx/nginx.conf
  copy conf /etc/nginx/default.d
  EXPOSE 80
  CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf"]
EOF
filename = "${path.root}/localfile/${var.app_name}/${element(var.environments, count.index)}/Dockerfile"
count = "${length(var.environments)}"
}

### Create Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "NGINX" {
  name        = "${var.app_name}"
  description = "An API Gateway built on NGINX running on top of Elastic Beanstalk and configured by Terraform"
}
### Create Elastic Beanstalk environments# Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "NGINX" {
  name = "${aws_elastic_beanstalk_application.NGINX.name}-${element(var.environments, count.index)}"
  application         = "${aws_elastic_beanstalk_application.NGINX.name}"
  solution_stack_name = "64bit Amazon Linux 2018.03 v2.10.0 running Docker 17.12.1-ce"
  tier                = "WebServer"
  count               = "${length(var.environments)}"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value = "${var.instance_size}"
  }
  setting {
     namespace = "aws:ec2:vpc"
     name      = "VPCId"
     value     = "${var.vpc_id}"
   }

   setting {
     namespace = "aws:ec2:vpc"                          ### this setting is the subnets for the worker instances launched by ELB
     name      = "Subnets"
     value     = "${join(",", var.instance_subnet_ids)}"
   }
   setting {
     namespace = "aws:ec2:vpc"
     name      = "ELBSubnets"
     value     = "${join(",", var.lb_subnet_ids)}"
   }


  # There are a LOT of settings, see here for the basic list:
  # https://is.gd/vfB51g

   # You can set the environment type, single or LoadBalanced
   setting {
     namespace = "aws:elasticbeanstalk:environment"
     name      = "EnvironmentType"
     value     = "LoadBalanced"
   }
   setting {
     namespace = "aws:elasticbeanstalk:cloudwatch:logs"
     name      = "StreamLogs"
     value     = "true"
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
   setting {
     namespace = "aws:elasticbeanstalk:application"
     name      = "Application Healthcheck URL"
     value     = "/"
   }
   setting {
     namespace = "aws:ec2:vpc"
     name      = "AssociatePublicIpAddress"
     value     = "false"
   }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value = "${var.max_nodes}"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "${var.ec2_instance_profile_name}"
  }
  depends_on = ["local_file.dockerfile"]

  provisioner "local-exec"{
    command = "${path.module}/scripts/dockerbuild.sh"
    working_dir = "${path.root}/localfile/${var.app_name}/${element(var.environments, count.index)}"
    interpreter = ["bash"]
   environment {
     AWS_PROFILE_NAME = "${var.aws_profile}"
     REGION = "${var.aws_region}"
     NAME = "${element(aws_elastic_beanstalk_application.NGINX.*.name, count.index)}"
     STAGE = "${element(var.environments, count.index)}"
     PORT = "80"
   }
 }
}
