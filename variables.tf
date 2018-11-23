variable "profile" {
  description = "Name of your profile inside ~/.aws/credentials"
}

variable "region" {
  default     = "eu-central-1"
  description = "Defines where your app should be deployed"
}

variable "azs" {
    default = "eu-central-1a,eu-central-1b,eu-central-1c"
    description = "availability zones to use"
}

variables "s3_state_bucket" {
  type = "map"
  description "bucket should be the name of an aws bucket for holding terraform state,
               key in this bucket underwhich the state data should be stored"
  default = {
    bucket = ""
    key = ""
}
variable "network_name"{
  type = "string"
  default "terraform"
}
variable "deployment_s3_bucket"
{
  type ="string"
  description = "Global S3 bucket for Elastic Beanstalk Deployment files, i.e BenLeibigEBDeployments"
}
