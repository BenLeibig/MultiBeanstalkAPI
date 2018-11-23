#--------------------------------------------------------------
# This module creates a docker/beanstalk instance with everything required for deployment.
# One environment/stage is created for each stage listed in the environments list
#--------------------------------------------------------------

variable "app_name"            { }
variable "app_description"            { }
variable "environments" {
   default = ["dev"]
   type = "list"
}
variable "max_nodes" {
  default ="4"
}
variable "min_nodes" {
  default ="2"
}
variable "instance_size" {
  default="t2.micro"
}
variable "healthcheck_url"{
  default="/_health"
}
variable "ec2_instance_profile_name" {
  default = "beanstalk-ec2-user"
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

resource "aws_ecr_repository" "container_repository" {
  name = "${var.app_name}"
}


resource "aws_elastic_beanstalk_application" "beanstalk_application" {
  name        = "${var.app_name}"
  description = "${var.app_description}"
}


# Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "beanstalk_application_environment" {
  name = "${var.app_name}-${element(var.environments, count.index)}"
  application         = "${aws_elastic_beanstalk_application.beanstalk_application.name}"
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
   /*
   setting {
     namespace = "aws:ec2:vpc"                         #### This prevents the loadbalancer from having a public IP and being accessible from the internet
     name      = "ELBScheme"
     value     = "internal"
   }
   */
   setting {
     namespace = "aws:ec2:vpc"                         #### False prevents the loadbalancer from having a public IP and being accessible from the internet
     name      = "AssociatePublicIpAddress"
     value     = "true"
   }

  #
  # There are a LOT of settings, see here for the basic list:
  # https://is.gd/vfB51g

   # You can set the environment type, single or LoadBalanced
   setting {
     namespace = "aws:elasticbeanstalk:environment"
     name      = "EnvironmentType"
     value     = "LoadBalanced"
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
     value     = "${var.healthcheck_url}"
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
}

### Write local NGINX config file segement
resource "local_file" "nginx_conf" {
  count               = "${length(var.environments)}"
  filename = "${path.root}/localfile/nginx-bs-proxy/${element(var.environments, count.index)}/conf/${var.app_name}.proxy.conf"
  content     = <<EOF
  location /${var.app_name} {
      proxy_set_header x-Real-Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_pass http://${element(aws_elastic_beanstalk_environment.beanstalk_application_environment.*.cname, count.index)}/;
        }
EOF
  }

output "local_conf_files"{
  value = "${local_file.nginx_conf.*.filename}"
}
