output "id" {
  description = "The integration's ID."
  value       = try(spotlight_integration.this[0].id, null)
}

output "address" {
  description = "The integration's address in the workspace, as in `core/linear`."
  value       = try(spotlight_integration.this[0].address, null)
}

output "tools" {
  description = "The integration's tools, by name, to the name a station or hook gives it by, as in `{ comment = \"linear.comment\" }`."
  value       = try(spotlight_integration.this[0].tools, {})
}

output "webhook_url" {
  description = "The URL to give the Linear webhook."
  value       = var.create ? "${trimsuffix(var.spotlight_url, "/")}/api/webhooks/w/${var.workspace}/t/${var.team}/${var.integration}" : null
}

output "happenings" {
  description = "The happenings the integration raises: `labelled` when an issue gets `label`, `commented` when someone comments on an issue, `completed` and `canceled` when an issue moves to a state of that type. `labelled` is null when `label` is null."
  value = {
    labelled  = var.label == null ? null : "${var.integration}.issue.labelled"
    commented = "${var.integration}.comment.created"
    completed = "${var.integration}.issue.completed"
    canceled  = "${var.integration}.issue.canceled"
  }
}

output "marks" {
  description = "The mark kinds the integration keeps on a task: `issue`, the Linear issue's ID, which finds the task, and `identifier`, as in `ENG-123`."
  value = {
    issue      = local.issue_mark
    identifier = local.identifier_mark
  }
}

output "signing_secret_name" {
  description = "The name of the workspace secret that holds the signing secret."
  value       = var.create ? local.signing_secret_name : null
}
