org_name   = "{{ .nuon.org.name }}"
org_id     = "{{ .nuon.org.id }}"
install_id = "{{ .nuon.install.id }}"

region                = "{{ .nuon.install_stack.outputs.region }}"
management_account_id = "{{ .nuon.sandbox.outputs.account.id }}"

root_domain = "{{ .nuon.inputs.inputs.root_domain }}"

cluster = {
  arn                        = "{{ .nuon.sandbox.outputs.cluster.arn }}"
  certificate_authority_data = "{{ .nuon.sandbox.outputs.cluster.certificate_authority_data }}"
  endpoint                   = "{{ .nuon.sandbox.outputs.cluster.endpoint }}"
  name                       = "{{ .nuon.sandbox.outputs.cluster.name }}"
  platform_version           = "{{ .nuon.sandbox.outputs.cluster.platform_version }}"
  oidc_issuer_url            = "{{ .nuon.sandbox.outputs.cluster.oidc_issuer_url }}"
  oidc_provider_arn          = "{{ .nuon.sandbox.outputs.cluster.oidc_provider_arn }}"
}

ecr = {
  id  = "{{ .nuon.sandbox.outputs.ecr.registry_id }}"
  arn = "{{ .nuon.sandbox.outputs.ecr.repository_arn }}"
}
ctl_api_role_arn = "{{ .nuon.components.ctl_api_role.outputs.iam_role_arn }}"
