# Management Component

Mangement infrastructure components in use by all orgs and apps and the roles necessary.

## Requirements

| Name                                                                        | Version   |
| --------------------------------------------------------------------------- | --------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform)    | >= 1.11.3 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                      | >= 5.94.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement_kubectl)          | >= 1.19   |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement_kubernetes) | >= 2.36.0 |

## Providers

| Name                                             | Version   |
| ------------------------------------------------ | --------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | >= 5.94.1 |

## Modules

| Name                                                                             | Source                                                    | Version  |
| -------------------------------------------------------------------------------- | --------------------------------------------------------- | -------- |
| <a name="module_dns_access_role"></a> [dns_access_role](#module_dns_access_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | >= 5.1.0 |
| <a name="module_org_access_role"></a> [org_access_role](#module_org_access_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | >= 5.1.0 |

## Resources

| Name                                                                                                                                                | Type        |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_iam_policy.dns_access_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)                          | resource    |
| [aws_iam_policy.ecr_iam_access_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)                      | resource    |
| [aws_iam_policy.orgs_iam_access_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)                     | resource    |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)                                   | resource    |
| [aws_iam_policy_document.dns_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)            | data source |
| [aws_iam_policy_document.dns_access_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)      | data source |
| [aws_iam_policy_document.ecr_iam_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)        | data source |
| [aws_iam_policy_document.ecr_iam_access_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)  | data source |
| [aws_iam_policy_document.orgs_iam_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)       | data source |
| [aws_iam_policy_document.orgs_iam_access_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name                                                                              | Description                                                                                                    | Type                                                                                                                                                            | Default | Required |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | :------: |
| <a name="input_cluster"></a> [cluster](#input_cluster)                            | EKS Cluster access details passed through from the sandbox.                                                    | <pre>object({<br/> arn = string<br/> certificate_authority_data = string<br/> endpoint = string<br/> name = string<br/> platform_version = string<br/> })</pre> | n/a     |   yes    |
| <a name="input_ctl_api_role_arn"></a> [ctl_api_role_arn](#input_ctl_api_role_arn) | The role ARN for the CTL API k8s service account which will be allowed to assume the roles created here.       | `string`                                                                                                                                                        | n/a     |   yes    |
| <a name="input_ecr"></a> [ecr](#input_ecr)                                        | ECR details passed through from the sandbox.                                                                   | <pre>object({<br/> id = string<br/> arn = string<br/> })</pre>                                                                                                  | n/a     |   yes    |
| <a name="input_install_id"></a> [install_id](#input_install_id)                   | n/a                                                                                                            | `string`                                                                                                                                                        | n/a     |   yes    |
| <a name="input_org_id"></a> [org_id](#input_org_id)                               | n/a                                                                                                            | `string`                                                                                                                                                        | n/a     |   yes    |
| <a name="input_org_name"></a> [org_name](#input_org_name)                         | n/a                                                                                                            | `string`                                                                                                                                                        | n/a     |   yes    |
| <a name="input_region"></a> [region](#input_region)                               | basic details                                                                                                  | `string`                                                                                                                                                        | n/a     |   yes    |
| <a name="input_root_domain"></a> [root_domain](#input_root_domain)                | The root domain to create a zone for. This should be the same value as {{ .nuon.inputs.inputs.root\_domain }}. | `string`                                                                                                                                                        | n/a     |   yes    |

## Outputs

| Name                                                                                                     | Description              |
| -------------------------------------------------------------------------------------------------------- | ------------------------ |
| <a name="output_app_ecr_registry_id"></a> [app_ecr_registry_id](#output_app_ecr_registry_id)             | simple formats           |
| <a name="output_cluster"></a> [cluster](#output_cluster)                                                 | details from the sandbox |
| <a name="output_dns_management_role_arn"></a> [dns_management_role_arn](#output_dns_management_role_arn) | n/a                      |
| <a name="output_ecr"></a> [ecr](#output_ecr)                                                             | n/a                      |
| <a name="output_ecr_access_role"></a> [ecr_access_role](#output_ecr_access_role)                         | n/a                      |
| <a name="output_ecr_management_role_arn"></a> [ecr_management_role_arn](#output_ecr_management_role_arn) | n/a                      |
| <a name="output_org_access_role"></a> [org_access_role](#output_org_access_role)                         | full outputs             |
| <a name="output_org_management_role_arn"></a> [org_management_role_arn](#output_org_management_role_arn) | n/a                      |
| <a name="output_route53_zone"></a> [route53_zone](#output_route53_zone)                                  | n/a                      |

## DNS

1. Route53 Zone for `{{ .nuon.inputs.inputs.root_domain }}`.
2. IAM Role to manage Route53 Zone. Assumable by `ctl-api`'s service account.

## Org

1. IAM Role with permissions necessary to make IAM and ECR resources for each org and app. Assumable by `ctl-api`'s
   service account.

## ECR (wip)

The ECR repository from the sandbox is passed through as a variable.

1. A role that can manage the repo's contents.Assumable by `ctl-api`'s service account.
