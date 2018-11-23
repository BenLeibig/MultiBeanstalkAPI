

resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.app_name}"
  description = "${var.app_description}"
  depends_on = ["aws_elastic_beanstalk_application.beanstalk_application"]
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.proxy.id}"
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "beanstalk" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_method.proxy.resource_id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_elastic_beanstalk_application.beanstalk_application.name}-$${stageVariables.targetEnv}.${join(".",slice(split(".",aws_elastic_beanstalk_environment.beanstalk_application_environment.0.cname),1,length(split(".",aws_elastic_beanstalk_environment.beanstalk_application_environment.0.cname))))}/{proxy}"
  passthrough_behavior     = "WHEN_NO_MATCH"
 request_parameters {
   "integration.request.path.proxy" = "method.request.path.proxy"
 }
}
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = ["aws_api_gateway_integration.beanstalk" ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name = "" # see https://github.com/terraform-providers/terraform-provider-aws/issues/2918
  count = "${length(var.environments)}"
}
resource "aws_api_gateway_stage" "environment" {
  stage_name = "${element(var.environments, count.index)}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  deployment_id ="${element(aws_api_gateway_deployment.deployment.*.id, count.index)}"
  variables =
  { targetEnv = "${element(var.environments, count.index)}"  }
  count = "${length(var.environments)}"
}
