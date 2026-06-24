# data "aws_route53_zone" "private" {
#   # HACK: this sucks. there's not a way to query just by tags or whatever
#   name   = "${local.vars.pool}.${local.vars.region}.${var.env}.${local.vars.root_domain}"
#   vpc_id = data.aws_vpcs.vpcs.ids[0]
#   tags = {
#     environment = var.env
#     pool        = local.vars.pool
#   }
# }

data "utils_deep_merge_yaml" "vars" {
  input = [
    file("vars/defaults.yaml"),
    file("vars/${var.env}.yaml"),
  ]
}

data "aws_ecr_authorization_token" "ecr_token" {
  provider = aws.infra-shared-prod
}
