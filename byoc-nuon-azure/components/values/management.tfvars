# Azure compatibility adapter values for the management component.
management_account_id = "{{ .nuon.cloud_account.azure.subscription_id }}"

cluster = {
  name                       = "{{ .nuon.sandbox.outputs.cluster.name }}"
  endpoint                   = "{{ .nuon.sandbox.outputs.cluster.endpoint }}"
  certificate_authority_data = "{{ .nuon.sandbox.outputs.cluster.certificate_authority_data }}"
  oidc_provider              = "{{ .nuon.sandbox.outputs.cluster.oidc_issuer_url }}"
}

acr = {
  id           = "{{ .nuon.sandbox.outputs.acr.id }}"
  login_server = "{{ .nuon.sandbox.outputs.acr.login_server }}"
}

dns_domain      = "{{ .nuon.sandbox.outputs.nuon_dns.public_domain.name }}"
dns_zone_id     = "{{ or .nuon.sandbox.outputs.nuon_dns.public_domain.zone_id .nuon.sandbox.outputs.nuon_dns.public_domain.id }}"
dns_nameservers = []

# Azure-specific values for org runner provisioning
azure_tenant_id       = "{{ .nuon.cloud_account.azure.tenant_id }}"
azure_subscription_id = "{{ .nuon.cloud_account.azure.subscription_id }}"
azure_resource_group  = "{{ .nuon.install_stack.outputs.resource_group_name }}"
azure_oidc_issuer_url = "{{ .nuon.sandbox.outputs.cluster.oidc_issuer_url }}"
