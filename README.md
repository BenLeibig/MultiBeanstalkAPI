This is an example NodeJS/React application that makes use of redis and postgres.
It is built into docker containers using docker-compose for dev and travis-ci + beanstalk for production.

It also configures AWS API_Gateway and sets up an alternative NGINX based ingress router to route to all of the apis based on url context.

The terraform code in place is modularized and configure to scale up and run multiple other applications, with comments throughout the reference main.tf to explain.

### ALWAYS Run terraform plan before running an apply and make SURE you understand what will happen.  
Terraform can sometimes pull down entire environments and rebuild them to execute a change.  This can be fine if you are expecting it to happen, but can create total chaos if you're unaware.  

### Prerequisities

- A secert key and access key for an AWS IAM account with access to at least IAM, EC2, the S3 terraform state bucket, Beanstalk & Elastic Container Registry/Engine.  This account should be listed in as the first account in the terraform_admins list in the terraform.tfvars file along with any other accounts that will be used for terraforming.
- An S3 bucket for terraform state must be created in the same zone as the specified in the variables.tf file.  One may already exist if you use terraform in other places and it can be reused.  the bucket name along with a unique key for this terraform codebase in the said bucket should be speicfied in the s3_state_variable (see variables.tf).
- AWS CLI must be installed and  your profile must be setup inside `~/.aws/credentials` directory.
- Terraform

### Contents of repo
 - ```terraform/main.tf``` - The base terraform file
 - ```terraform/modules/SimpleHABeanstalk``` - A terraform module for provisioning beanstalk applications, it also writes out a little NGINX config segement for optional API rounting
 - ```terraform/modules/network``` - If you already have anything in terraform, this is probably already done.
 - ```terraform/modules/BeanstalkAPIgw``` - Builds multistaged beanstalk instances with API Gateway integration.  
-  ```terraform/IAMFoundation``` All required IAM configuration
-  ```NGINXBSProxy``` Builds and installs a proxy server to operate as an API Gateway an alterantive to AWS.


### Setup
0. in the `terraform` folder, copy the testapp.tfvars to be named terraform.tfvars.  Edit the terraform.tfvars and fill everything out.  Note that the profile should reference an AWS profile setup in the .aws folder which includes cli access credentials.
1. run ```terraform init```
2. Run ```terraform plan```
  - Fill out Name, Description & environment
  - Profile is name of your profile inside `~/.aws/credentials` file. Default profile is called `default`. You can insert many profiles inside `credentials` file.
  -  Note that you can predefine variables in the file terraform.tfvars to avoid being asked questions when you run terraform plan.
3. Run ```terraform import module.iam_foundation.aws_iam_user.tfadmin-user[0] [AWS_IAM_ACCCOUNT_NAME]``` where [AWS_IAM_ACCOUNT_NAME] is the name of the account mentioned in the prerequisites section above
  - This will import the account you setup in the aws console into the terraform view
3. Run ```terraform apply``` - this may take up to 15 minutes


### Rollbacking setup
```
terraform destroy
```
Note that this command will destroy everything, including the S3 bucket with all your old deployment files in it and the ECR with all your old docker containers.

# Specific documentation for the SimpleHABeanstalk module
### Setting up new applications and Environments
the file `terraform/main.tf` has a number of modulethat look something like this.

```
module "APPNAME-beanstalk" {
  source = "./modules/SimpleHABeanstalk"
  app_name = "APPNAME"
  app_description = "DESCRIBE YOUR APP"
  environments = "dev,test" # list one or more environments you want built here
  max_nodes = "4"
  min_nodes = "2" ## Ensures H/A
  instance_size = "t2.micro"
  healthcheck_url = "/_health"
}
```

To setup a new app, simply copy one of the module bloc, or this one above and change the app_name, app_description, and environments file to match your app.  You can also play with the other values, but the defaults should be good for the most part.

Make sure you commit your changes to the main.tf to the git repository and merge to master before applying them.  Terraform apply should be seen the same sort of action as deploying an app to production.
