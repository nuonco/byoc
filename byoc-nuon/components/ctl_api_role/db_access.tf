data "aws_iam_policy_document" "db_access" {
  statement {
    effect = "Allow"
    # sts:AssumeRole intentionally omitted: this policy attaches to the same role
    # as aws_iam_policy.ctl_api, which already grants it scoped to the management
    # roles. Granting it again here on "*" would undo that scoping.
    actions = [
      "s3:ListBucket",
      "s3:*Object",
    ]
    resources = ["*", ]
  }
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
  name   = "rds-access-byoc-nuon-${var.install_id}"
  policy = data.aws_iam_policy_document.db_access.json
}
