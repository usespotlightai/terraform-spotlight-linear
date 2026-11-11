# terraform-spotlight-linear

A Spotlight integration for Linear. An issue that gets the `spotlight` label opens a task on the team's delivery line, and Spotlight comments on the issue with a link to the task. A task's questions are posted as comments on its issue, and a comment on the issue answers the question. When the task is complete, Spotlight says so on the issue.

The module creates a `spotlight_integration` and, unless you keep them yourself, the two `spotlight_secret`s it uses: the webhook's signing secret, which verifies that deliveries come from Linear, and an API key, bound to `api.linear.app`. The integration also gives agents and hooks a `comment` tool.

```
Linear ──webhook (signed with the signing secret)──▶ webhook_url
                                                       │ verify, drop deliveries older than 60 s
                                                       │ and everything that user_id does
                                                       ▼
                     issue gets label    → opens a task on line_role, assigned to whoever added the label
                     comment on an issue → a note on the issue's task, and the answer to its question
                     issue completed     → linear.issue.completed, for a line's reactions
                     issue canceled      → linear.issue.canceled
                                                       │
task opened ────────commentCreate (API key)────────────┤ on the task's issue
task asks a question ─commentCreate (API key)──────────┤
task finished ──────commentCreate (API key)────────────┘
```

## Version constraints

Terraform 1.11 is the floor because `value_wo` on `spotlight_secret` is a **write-only** attribute: Terraform sends the secret to Spotlight but never stores it in the plan or the state. `signing_secret` and `api_key` are ephemeral variables for the same reason. Spotlight only takes new values when `secret_version` changes.

The module needs the Spotlight provider 0.1.0-rc.4 or later, the first release that calls the control plane's `/api/v1` resource API.

The module and the provider are release candidates. Terraform selects a release candidate only for an exact version, such as `version = "0.1.0-rc.4"`. It skips release candidates for `>=` and `~>`. Thus, pin the module and the provider to exact versions, as in [Usage](#usage).

Spotlight checks the integration's definition when you plan and apply, not the provider. If the definition format changes in a Spotlight release, update the module to the release that follows it.

## Usage

```hcl
terraform {
  required_providers {
    spotlight = {
      source  = "usespotlightai/spotlight"
      version = "0.1.0-rc.4"
    }
  }
}

module "linear" {
  source  = "usespotlightai/linear/spotlight"
  version = "0.1.0-rc.1" # x-release-please-version

  workspace = "acme"
  team      = "core"

  user_id        = "2c5e3b4a-1f0d-4e6b-9a7c-8d2e1f3a4b5c"
  signing_secret = var.linear_signing_secret
  api_key        = var.linear_api_key
}

output "linear_webhook_url" {
  value = module.linear.webhook_url
}
```

### Give an issue to Spotlight

Add the label named in `label`, `spotlight` by default, to an issue, or create the issue with it. Spotlight compares the label's name without case. The issue opens a task on the team's line whose role is `line_role`, `delivery` by default, at the line's first work station. The task's title is the issue's title, and its description is the issue's description followed by the issue's address. The task is assigned to the Spotlight member who uses the email of the Linear user who added the label: as their sign-in email, or as an additional email they verified in Spotlight under Settings › Emails. See [Add another email to your account](https://docs.usespotlight.ai/docs/administration/add-another-email-to-your-account). With no such member, the task has no assignee.

The task keeps the issue's ID, which finds the task for every later event about the issue, and the issue's identifier, as in `ENG-123`. The `marks` output names both kinds. Removing the label and adding it again does not open a second task. Set `label` to `null` to open no tasks from Linear and keep only the comments and happenings.

When the issue opens a task, Spotlight comments on the issue with a link to the task. Set `acknowledge` to `false` to turn the comment off.

### Answer a question

When a task asks a person, Spotlight posts the question as a comment on the task's issue, with a link to answer it in Spotlight. A task that has no Linear issue posts nothing to Linear. A comment on the issue, from anyone but `user_id`, is a note on the task, and answers the question the task waits on. The note shows the avatar of the member who uses the email of the Linear user.

When the task reaches the end of its line, Spotlight comments on the issue that the task is complete, with its pull request.

### React to a finished issue

The integration raises `linear.issue.completed` when an issue moves to a state of type completed, and `linear.issue.canceled` when it moves to a canceled one. Give them to a line's reactions, through the `happenings` output, to move the task:

```hcl
reactions = [
  { happening = module.linear.happenings.completed, to = "completed" },
]
```

### Prepare Linear

Spotlight acts in Linear as the user whose API key it holds, and ignores everything that user does, so that its own comments never answer its questions. Use a Linear member for Spotlight alone, not a person's account: what that person does in Linear would be ignored too.

1. Sign in to Linear as the Spotlight member, and create a personal API key under Settings › Account › Security & access. Give it at least the permissions to read and to create comments. Copy it into `api_key`.
2. Find the member's user ID, and give it in `user_id`:

   ```bash
   curl -s https://api.linear.app/graphql \
     -H "Authorization: $LINEAR_API_KEY" \
     -H 'Content-Type: application/json' \
     -d '{"query":"{ viewer { id } }"}'
   ```

3. As a Linear admin, create a webhook under Settings › API › Webhooks. Give `https://app.usespotlight.ai/api/webhooks/w/<workspace slug>/t/<team key>/linear` as its URL. That address is the `webhook_url` output, known before you apply. Choose the team or all public teams, and the data change events `Issues` and `Comments`.
4. Copy the webhook's signing secret into `signing_secret`.
5. Run `terraform apply`.

On a self-hosted Spotlight, set `spotlight_url` to your deployment's address so `webhook_url` is right.

### Comment from a hook or a station

Name the tool through the `tools` output, so a plan fails if the tool is renamed or removed:

```hcl
resource "spotlight_hook" "merges" {
  team_id = data.spotlight_team.core.id
  key     = "comment-merges"
  on      = "pull-request.merged"
  steps = [
    {
      name = "comment"
      call = module.linear.tools["comment"]
      with = {
        body = "Merged $${{ event.url }}"
      }
    },
  ]
}
```

Without `issue`, the tool comments on the issue of the task. Give `issue` as the issue's ID or identifier, as in `ENG-123`, to comment on another issue. Set `comment_approval` to make a person approve each comment first.

### Keep the secrets yourself

To manage the secrets outside this module, for example read from AWS Secrets Manager, set `create_secrets = false` and give their names in `signing_secret_name` and `api_key_name`. Bind the API key's secret to `api.linear.app` in the `authorization` header, with no prefix.

### Rotating the secrets

Give the new values in `signing_secret` and `api_key`, and raise `secret_version`. Terraform sends both values again.

## Conditional creation

```hcl
module "linear" {
  source = "usespotlightai/linear/spotlight"

  create = false
  # ...
}
```

## Examples

- [complete](examples/complete)

## Testing

```sh
terraform init -backend=false
terraform test    # tests/*.tftest.hcl, against a mocked spotlight provider
```

## Contributing

Formatting, the generated sections of every README, tflint and `terraform validate` run through [pre-commit](https://pre-commit.com), which needs [terraform-docs](https://terraform-docs.io) and [tflint](https://github.com/terraform-linters/tflint) installed:

```sh
pre-commit install
pre-commit run --all-files
```

CI runs the same hooks and the tests on every pull request. Pull requests are squash-merged, and the title becomes the commit, so the title is a Conventional Commit with the Linear issue as the scope, as in `feat(SPO-123): Add a project input`. Releases follow [semantic versioning](https://semver.org) and come from [release-please](https://github.com/googleapis/release-please): after each merge to `main` it updates one release pull request with the next version, the `version` in this README's usage example and the [CHANGELOG.md](CHANGELOG.md) entries. Merging that pull request tags the release and publishes it, and the Terraform Registry picks it up. `feat` and `fix` commits make a release. While `release-please-config.json` has `"prerelease": true`, each release is the next `-rc.N`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_spotlight"></a> [spotlight](#requirement\_spotlight) | >= 0.1.0-rc.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_spotlight"></a> [spotlight](#provider\_spotlight) | >= 0.1.0-rc.4 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [spotlight_integration.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/integration) | resource |
| [spotlight_secret.api_key](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/secret) | resource |
| [spotlight_secret.signing](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/secret) | resource |
| [spotlight_team.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/data-sources/team) | data source |
| [spotlight_workspace.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/data-sources/workspace) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_team"></a> [team](#input\_team) | The key of the team the integration belongs to, as in `core`. | `string` | n/a | yes |
| <a name="input_user_id"></a> [user\_id](#input\_user\_id) | The ID of the Linear user that owns `api_key`. Spotlight ignores what this user does in Linear, so its own comments never answer a question or open a task. | `string` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | The slug of the Spotlight workspace, as in `acme`. | `string` | n/a | yes |
| <a name="input_acknowledge"></a> [acknowledge](#input\_acknowledge) | Whether Spotlight comments on an issue, with a link to the task, when the issue opens a task. | `bool` | `true` | no |
| <a name="input_api_key"></a> [api\_key](#input\_api\_key) | A Linear API key (`lin_api_`) of the user `user_id`. Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_api_key_name"></a> [api\_key\_name](#input\_api\_key\_name) | The name of the workspace secret that holds the API key. | `string` | `"LINEAR_API_KEY"` | no |
| <a name="input_comment_approval"></a> [comment\_approval](#input\_comment\_approval) | When set, each use of the `comment` tool first asks a person, who is shown this text. Null lets agents and hooks comment without asking. | `string` | `null` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create the integration and its secrets. False creates nothing. | `bool` | `true` | no |
| <a name="input_create_secrets"></a> [create\_secrets](#input\_create\_secrets) | Whether the module creates the two secrets from `signing_secret` and `api_key`. False uses the workspace secrets named `signing_secret_name` and `api_key_name`, which you keep yourself; the API key's secret must then be bound to `api.linear.app` in the `authorization` header, with no prefix. | `bool` | `true` | no |
| <a name="input_integration"></a> [integration](#input\_integration) | The integration's name in the team. It is the last part of the webhook address, and the first part of every happening and mark kind the integration raises, as in `linear.issue`. Fixed for the integration's life. | `string` | `"linear"` | no |
| <a name="input_label"></a> [label](#input\_label) | The name of the Linear label that gives an issue to Spotlight, compared without case. An issue that gets the label opens a task. Null opens no task from Linear. | `string` | `"spotlight"` | no |
| <a name="input_line_role"></a> [line\_role](#input\_line\_role) | The role of the line that an issue with `label` opens a task on, as in `delivery`. | `string` | `"delivery"` | no |
| <a name="input_logo"></a> [logo](#input\_logo) | The mark the web app shows for the integration, as a base64 data URI of an SVG, PNG, WebP or JPEG image or as an https address. By default, the mark of Linear. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | What the integration is called in the web app. | `string` | `"Linear"` | no |
| <a name="input_secret_version"></a> [secret\_version](#input\_secret\_version) | Change it when `signing_secret` or `api_key` changes, so Terraform sends the new values to Spotlight. | `number` | `1` | no |
| <a name="input_signing_secret"></a> [signing\_secret](#input\_signing\_secret) | The signing secret of the Linear webhook. Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_signing_secret_name"></a> [signing\_secret\_name](#input\_signing\_secret\_name) | The name of the workspace secret that holds the signing secret. | `string` | `"LINEAR_SIGNING_SECRET"` | no |
| <a name="input_spotlight_url"></a> [spotlight\_url](#input\_spotlight\_url) | The address of your Spotlight, used only for the `webhook_url` output. Change it for a self-hosted Spotlight. | `string` | `"https://app.usespotlight.ai"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | The integration's address in the workspace, as in `core/linear`. |
| <a name="output_api_key_name"></a> [api\_key\_name](#output\_api\_key\_name) | The name of the workspace secret that holds the API key. |
| <a name="output_happenings"></a> [happenings](#output\_happenings) | The happenings the integration raises: `labelled` when an issue gets `label`, `commented` when someone comments on an issue, `completed` and `canceled` when an issue moves to a state of that type. `labelled` is null when `label` is null. |
| <a name="output_id"></a> [id](#output\_id) | The integration's ID. |
| <a name="output_marks"></a> [marks](#output\_marks) | The mark kinds the integration keeps on a task: `issue`, the Linear issue's ID, which finds the task, and `identifier`, as in `ENG-123`. |
| <a name="output_signing_secret_name"></a> [signing\_secret\_name](#output\_signing\_secret\_name) | The name of the workspace secret that holds the signing secret. |
| <a name="output_tools"></a> [tools](#output\_tools) | The integration's tools, by name, to the name a station or hook gives it by, as in `{ comment = "linear.comment" }`. |
| <a name="output_webhook_url"></a> [webhook\_url](#output\_webhook\_url) | The URL to give the Linear webhook. |
<!-- END_TF_DOCS -->

## License

Apache 2.0. See [LICENSE](LICENSE).
