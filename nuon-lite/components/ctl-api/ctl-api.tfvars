region                         = "{{ .nuon.install_stack.outputs.region }}"
install_id                     = "{{ .nuon.install.id }}"
org_id                         = "{{ .nuon.org.id }}"
vpc_id                         = "{{ .nuon.install_stack.outputs.vpc_id }}"
vpc_cidr                       = "{{ .nuon.components.ecs_runtime.outputs.vpc_cidr }}"
cluster_arn                    = "{{ .nuon.components.ecs_runtime.outputs.cluster_arn }}"
cloud_map_namespace_id         = "{{ .nuon.components.ecs_runtime.outputs.cloud_map_namespace_id }}"
log_group_name                 = "{{ .nuon.components.ecs_runtime.outputs.log_group_name }}"
execution_role_arn             = "{{ .nuon.components.task_iam.outputs.execution_role_arn }}"
task_role_arn                  = "{{ .nuon.components.task_iam.outputs.ctl_api_task_role_arn }}"
aurora_credentials_secret_arn  = "{{ .nuon.components.ctl_api_db.outputs.credentials_secret_arn }}"
aurora_cluster_endpoint        = "{{ .nuon.components.ctl_api_db.outputs.cluster_endpoint }}"
alb_https_listener_arn         = "{{ .nuon.components.public_ingress.outputs.https_listener_arn }}"
alb_security_group_id          = "{{ .nuon.components.public_ingress.outputs.alb_security_group_id }}"
ctl_api_image                  = "{{ .nuon.components.ctl_api_image.outputs.image.repository }}:{{ .nuon.components.ctl_api_image.outputs.image.tag }}"
public_root_domain             = "{{ .nuon.install.sandbox.outputs.nuon_dns.public_domain.name }}"
admin_host                     = "admin.{{ .nuon.install.sandbox.outputs.nuon_dns.public_domain.name }}"

clickhouse_host                = "{{ .nuon.inputs.inputs.clickhouse_host }}"
clickhouse_port                = "{{ .nuon.inputs.inputs.clickhouse_port }}"
clickhouse_database            = "{{ .nuon.inputs.inputs.clickhouse_database }}"
clickhouse_username            = "{{ .nuon.inputs.inputs.clickhouse_username }}"
clickhouse_tls                 = "{{ .nuon.inputs.inputs.clickhouse_tls }}"
clickhouse_password_secret_arn = "{{ .nuon.install_stack.outputs.clickhouse_cloud_password_arn }}"

# Temporal Cloud config is discovered by tag inside the module — no
# tfvars passthrough. The temporal-cloud component must apply before this
# component (declare via depends_on in the component toml).

nuon_env = "{{ .nuon.inputs.inputs.env }}"

auth_provider_type            = "{{ .nuon.inputs.inputs.nuon_auth_provider_type }}"
auth_issuer_url               = "{{ .nuon.inputs.inputs.nuon_auth_issuer_url }}"
auth_client_id                = "{{ .nuon.inputs.inputs.nuon_auth_client_id }}"
auth_allow_all_users          = "{{ .nuon.inputs.inputs.nuon_auth_allow_all_users }}"
auth_allowed_domains          = "{{ .nuon.inputs.inputs.nuon_auth_allowed_domains }}"
auth_session_key_secret_arn   = "{{ .nuon.install_stack.outputs.nuon_auth_session_key_arn }}"
auth_client_secret_secret_arn = "{{ .nuon.install_stack.outputs.nuon_auth_client_secret_arn }}"

github_app_id             = "{{ .nuon.inputs.inputs.github_app_id }}"
github_app_client_id      = "{{ .nuon.inputs.inputs.github_app_client_id }}"
github_app_name           = "{{ .nuon.inputs.inputs.github_app_name }}"
github_app_key_secret_arn = "{{ .nuon.install_stack.outputs.github_app_key_arn }}"

slack_client_id                   = "{{ .nuon.inputs.inputs.slack_client_id }}"
slack_oauth_redirect_url          = "{{ .nuon.inputs.inputs.slack_oauth_redirect_url }}"
slack_client_secret_secret_arn    = "{{ .nuon.install_stack.outputs.slack_client_secret_arn }}"
slack_signing_secret_secret_arn   = "{{ .nuon.install_stack.outputs.slack_signing_secret_arn }}"
slack_state_jwt_secret_secret_arn = "{{ .nuon.install_stack.outputs.slack_state_jwt_secret_arn }}"

loops_api_key_secret_arn = "{{ .nuon.install_stack.outputs.loops_api_key_arn }}"
