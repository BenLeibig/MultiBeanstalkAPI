variable "TFadmins"{
  type="list"
  description="list of accounts that should have admin access"
}
resource "aws_iam_group" "tfadmins-group"{
  name = "terraform-admins"
}


resource "aws_iam_user_group_membership" "tfadmin-attach"{
  user = "${element(var.TFadmins, count.index)}"
  groups = ["${aws_iam_group.tfadmins-group.name}"]
  count = "${length(var.TFadmins)}"
}

resource "aws_iam_policy" "tfadmins-policy"{
  name = "terraform-admin"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_group_policy_attachment" "tfadmin"
{
  group = "${aws_iam_group.tfadmins-group.name}"
  policy_arn = "${aws_iam_policy.tfadmins-policy.arn}"
}
