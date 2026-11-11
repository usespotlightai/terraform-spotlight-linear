# Complete Linear integration

A Linear integration on the `core` team of the `acme` workspace that creates its signing secret, opens a task on the delivery line for each issue that gets the `agent` label, and asks a person before each use of the `comment` tool. A second instance shows `create = false`, which creates nothing.

## Usage

Prepare Linear first (see [Prepare Linear](../../README.md#prepare-linear)), then:

```bash
terraform init
terraform plan
terraform apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_spotlight"></a> [spotlight](#requirement\_spotlight) | >= 0.1.0-rc.4 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_linear"></a> [linear](#module\_linear) | ../.. | n/a |
| <a name="module_linear_disabled"></a> [linear\_disabled](#module\_linear\_disabled) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_linear_signing_secret"></a> [linear\_signing\_secret](#input\_linear\_signing\_secret) | The signing secret of the Linear webhook. | `string` | n/a | yes |
| <a name="input_spotlight_url"></a> [spotlight\_url](#input\_spotlight\_url) | The Spotlight the integration is created in. | `string` | `"https://app.usespotlight.ai"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_happenings"></a> [happenings](#output\_happenings) | The happenings the integration raises. |
| <a name="output_tools"></a> [tools](#output\_tools) | The integration's tools, by name. |
| <a name="output_webhook_url"></a> [webhook\_url](#output\_webhook\_url) | The URL to give the Linear webhook. |
<!-- END_TF_DOCS -->
