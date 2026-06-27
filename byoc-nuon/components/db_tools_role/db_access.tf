data "aws_iam_policy_document" "db_access" {
  statement {
    effect = "Allow"
    actions = [
      "rds-db:connect",
    ]
    resources = [
      format("arn:aws:rds-db:%s:%s:dbuser:%s/%s",
        var.region,
        data.aws_caller_identity.current.account_id,
        var.db_instance_resource_id,
        "ctl_api",
      ),
    ]
  }
}

resource "aws_iam_policy" "db_access" {
  name   = "rds-access-byoc-nuon-db-tools-${var.install_id}"
  policy = data.aws_iam_policy_document.db_access.json
}
