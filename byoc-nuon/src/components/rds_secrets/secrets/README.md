# Secrets Module

Copies secrets from secrets by ARN and creates k8s secrets w/ the given values.

Note: only concerned with `key=value` type secrets.

## Requirements

| Name                                                                        | Version   |
| --------------------------------------------------------------------------- | --------- |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                      | >= 5.94.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement_kubectl)          | >= 1.19   |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement_kubernetes) | >= 2.36.0 |

## Providers

| Name                                                         | Version   |
| ------------------------------------------------------------ | --------- |
| <a name="provider_aws"></a> [aws](#provider_aws)             | >= 5.94.1 |
| <a name="provider_kubectl"></a> [kubectl](#provider_kubectl) | >= 1.19   |

## Modules

No modules.

## Resources

| Name                                                                                                                                                      | Type        |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [kubectl_manifest.secret](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest)                                     | resource    |
| [aws_secretsmanager_secret.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret)                 | data source |
| [aws_secretsmanager_secret_version.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name                                                         | Description                                              | Type     | Default | Required |
| ------------------------------------------------------------ | -------------------------------------------------------- | -------- | ------- | :------: |
| <a name="input_arn"></a> [arn](#input_arn)                   | the arn of the AWS Secret Manaer Secret you want to copy | `string` | n/a     |   yes    |
| <a name="input_name"></a> [name](#input_name)                | the name of secret                                       | `string` | n/a     |   yes    |
| <a name="input_namespace"></a> [namespace](#input_namespace) | the namespace to create the secret in                    | `string` | n/a     |   yes    |

## Outputs

| Name                                                              | Description |
| ----------------------------------------------------------------- | ----------- |
| <a name="output_name"></a> [name](#output_name)                   | n/a         |
| <a name="output_namespace"></a> [namespace](#output_namespace)    | n/a         |
| <a name="output_uuid"></a> [uuid](#output_uuid)                   | n/a         |
| <a name="output_version_id"></a> [version_id](#output_version_id) | n/a         |
