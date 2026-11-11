mock_provider "spotlight" {
  mock_data "spotlight_workspace" {
    defaults = {
      id = "5b1e9d2c-7a43-4f8e-b6c0-3d9a8e1f2b57"
    }
  }

  mock_data "spotlight_team" {
    defaults = {
      id = "3f8a1c2e-6b4d-4e7a-9c1f-0d2b5e8a7c63"
    }
  }
}

variables {
  workspace      = "acme"
  team           = "core"
  signing_secret = "lin_wh_test"
}

run "creates_the_secret_and_the_integration" {
  assert {
    condition     = spotlight_secret.signing[0].workspace_id == "5b1e9d2c-7a43-4f8e-b6c0-3d9a8e1f2b57" && spotlight_secret.signing[0].name == "LINEAR_SIGNING_SECRET"
    error_message = "The signing secret goes in the workspace, as LINEAR_SIGNING_SECRET."
  }

  assert {
    condition     = length(spotlight_secret.signing[0].bindings) == 0
    error_message = "The signing secret is never sent anywhere."
  }

  assert {
    condition     = spotlight_integration.this[0].team_id == "3f8a1c2e-6b4d-4e7a-9c1f-0d2b5e8a7c63"
    error_message = "The integration belongs to the team."
  }

  assert {
    condition     = output.webhook_url == "https://app.usespotlight.ai/api/webhooks/w/acme/t/core/linear"
    error_message = "The webhook address is the team's address for the integration."
  }
}

run "verifies_deliveries_from_linear" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.verify.hmac.secret == "secret.LINEAR_SIGNING_SECRET" && spotlight_integration.this[0].definition.webhook.verify.hmac.header == "linear-signature"
    error_message = "Deliveries are verified with the signing secret, from the Linear-Signature header."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.verify.hmac.freshness.within == "60s" && strcontains(spotlight_integration.this[0].definition.webhook.verify.hmac.freshness.at, "body.webhookTimestamp) / 1000")
    error_message = "A delivery older than a minute is refused, by its timestamp in milliseconds."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.delivery == "$${{ headers[\"linear-delivery\"] }}"
    error_message = "A delivery Linear sends again is read once."
  }

}

run "acts_in_linear_as_an_app" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.connection.oauth2.authorize == "https://linear.app/oauth/authorize?actor=app" && spotlight_integration.this[0].definition.connection.oauth2.token == "https://api.linear.app/oauth/token"
    error_message = "The team connects Linear through OAuth, and Spotlight acts as the app, not as the person who connected."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.connection.oauth2.scopes == ["comments:create"]
    error_message = "The connection asks only to create comments."
  }

  assert {
    condition     = alltrue([for each in ["post-comment", "comment"] : spotlight_integration.this[0].definition.actions[each].request.auth.oauth2.connection == true])
    error_message = "Every request to Linear uses the team's connection."
  }
}

run "opens_a_task_from_a_labelled_issue" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.happening == "linear.issue.labelled" && spotlight_integration.this[0].definition.webhook.events[0].raise.opens.lineRole == "delivery"
    error_message = "A labelled issue opens a task on the delivery line."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.webhook.events[0].when, "l.name.lowerAscii() == \"spotlight\"") && strcontains(spotlight_integration.this[0].definition.webhook.events[0].when, "!(l.id in body.updatedFrom.labelIds)")
    error_message = "Only an issue that gets the spotlight label now opens a task."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.marks[0].kind == "linear.issue" && spotlight_integration.this[0].definition.webhook.events[0].raise.marks[0].value == "$${{ body.data.id }}" && spotlight_integration.this[0].definition.webhook.events[0].raise.marks[1].find == false
    error_message = "The task is found by the issue's ID, and keeps its identifier."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.webhook.events[0].raise.opens.assignBy.email, "body.actor.email")
    error_message = "The task is assigned to the person who labelled the issue."
  }
}

run "compares_the_label_without_case" {
  command = plan

  variables {
    label     = "Agent Ready"
    line_role = "triage"
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.webhook.events[0].when, "== \"agent ready\"") && spotlight_integration.this[0].definition.webhook.events[0].raise.opens.lineRole == "triage"
    error_message = "The label is compared in lowercase, and the task opens on the given line."
  }
}

run "opens_no_task_without_a_label" {
  command = plan

  variables {
    label = null
  }

  assert {
    condition     = alltrue([for each in spotlight_integration.this[0].definition.webhook.events : !strcontains(each.raise.happening, "labelled")]) && output.happenings.labelled == null
    error_message = "Without a label, no issue opens a task."
  }
}

run "refuses_a_label_with_a_quote" {
  command = plan

  variables {
    label = "say \"hi\""
  }

  expect_failures = [var.label]
}

run "answers_with_a_comment" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[1].raise.happening == "linear.comment.created" && spotlight_integration.this[0].definition.webhook.events[1].raise.answers == true
    error_message = "A comment carries a message to the task, and answers its question."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[1].raise.marks[0].value == "$${{ body.data.issueId }}" && strcontains(spotlight_integration.this[0].definition.webhook.events[1].raise.author.email, "body.actor.email")
    error_message = "A comment finds the task by its issue, and names its author by email."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.webhook.events[1].when, "!((has(body.data.botActor) && body.data.botActor != null) || (") && strcontains(spotlight_integration.this[0].definition.webhook.events[1].when, "body.actor.type == \"OauthClient\")")
    error_message = "A comment by an app, Spotlight's own included, answers nothing."
  }
}

run "raises_completed_and_canceled" {
  command = plan

  assert {
    condition     = [for each in slice(spotlight_integration.this[0].definition.webhook.events, 2, 4) : each.raise.happening] == ["linear.issue.completed", "linear.issue.canceled"]
    error_message = "An issue moved to a completed or canceled state raises a happening."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.webhook.events[2].when, "has(body.updatedFrom.stateId)")
    error_message = "Only a change of state raises it."
  }
}

run "asks_on_the_issue" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.on["task.asked"][0].action == "post-comment" && strcontains(spotlight_integration.this[0].definition.on["task.asked"][0].to.thread, "\"linear.issue\" in task.marks")
    error_message = "A task's question is a comment on its issue, and a task without an issue posts nothing."
  }

  assert {
    condition     = startswith(spotlight_integration.this[0].definition.on["task.asked"][0].to.text, "$${{ ask.body + (ask.link != null") && strcontains(spotlight_integration.this[0].definition.on["task.asked"][0].to.text, "Answer in Spotlight")
    error_message = "The comment is the question, with a link to answer it in Spotlight."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.actions["post-comment"].request.url == "https://api.linear.app/graphql"
    error_message = "Comments go to the Linear API."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.actions["post-comment"].request.body.variables.input.issueId == "$${{ target.thread }}" && spotlight_integration.this[0].definition.actions["post-comment"].request.body.variables.input.body == "$${{ target.text }}"
    error_message = "A binding's comment goes to the issue it names."
  }
}

run "acknowledges_a_new_task_by_default" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.on["task.opened"][0].action == "post-comment" && strcontains(spotlight_integration.this[0].definition.on["task.opened"][0].to.text, "task.url")
    error_message = "An issue that opens a task gets a comment with the task's link."
  }
}

run "does_not_acknowledge_when_off" {
  command = plan

  variables {
    acknowledge = false
  }

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.on), "task.opened")
    error_message = "No acknowledgement is bound when acknowledge is false."
  }
}

run "tells_the_issue_when_the_task_is_complete" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.on["task.finished"][0].action == "post-comment" && strcontains(spotlight_integration.this[0].definition.on["task.finished"][0].to.text, "task.pullRequest")
    error_message = "A finished task comments on its issue, with its pull request."
  }
}

run "comments_from_a_tool" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.tools["comment"].action == "comment" && !contains(keys(spotlight_integration.this[0].definition.tools["comment"]), "approval")
    error_message = "The comment tool has no approval by default."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.tools["comment"].inputs.issue.default, "task.marks[\"linear.issue\"]")
    error_message = "Without an issue, the tool comments on the task's issue."
  }
}

run "asks_before_commenting_when_set" {
  command = plan

  variables {
    comment_approval = "The comment is visible to everyone in the Linear workspace."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.tools["comment"].approval.because == "The comment is visible to everyone in the Linear workspace."
    error_message = "The comment tool asks a person first."
  }
}

run "names_everything_after_the_integration" {
  command = plan

  variables {
    integration = "tracker"
  }

  assert {
    condition     = alltrue([for each in spotlight_integration.this[0].definition.webhook.events : startswith(each.raise.happening, "tracker.") && each.raise.marks[0].kind == "tracker.issue"])
    error_message = "Happenings and mark kinds start with the integration's name."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["task.asked"][0].to.thread, "task.marks[\"tracker.issue\"]") && output.webhook_url == "https://app.usespotlight.ai/api/webhooks/w/acme/t/core/tracker"
    error_message = "Questions find the issue by the integration's own mark, and the webhook address ends with its name."
  }
}

run "uses_an_existing_signing_secret" {
  command = plan

  variables {
    create_signing_secret = false
    signing_secret        = null
    signing_secret_name   = "ACME_LINEAR_SIGNING"
  }

  assert {
    condition     = length(spotlight_secret.signing) == 0
    error_message = "No secret is created."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.verify.hmac.secret == "secret.ACME_LINEAR_SIGNING"
    error_message = "The integration names the existing secret."
  }
}

run "creates_nothing_when_disabled" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = length(spotlight_integration.this) == 0 && length(spotlight_secret.signing) == 0
    error_message = "A disabled module creates no resources."
  }

  assert {
    condition     = output.id == null && output.webhook_url == null && output.tools == {}
    error_message = "A disabled module's resource outputs are null."
  }
}

run "refuses_a_missing_signing_secret" {
  command = plan

  variables {
    signing_secret = null
  }

  expect_failures = [var.signing_secret]
}

run "refuses_an_integration_name_with_a_dash" {
  command = plan

  variables {
    integration = "linear-ops"
  }

  expect_failures = [var.integration]
}

run "shows_the_mark_of_linear_by_default" {
  command = plan

  assert {
    condition     = startswith(spotlight_integration.this[0].definition.logo, "data:image/svg+xml;base64,") && base64decode(trimprefix(spotlight_integration.this[0].definition.logo, "data:image/svg+xml;base64,")) == file("logo.svg")
    error_message = "By default the integration shows the mark of Linear, from logo.svg."
  }
}

run "shows_the_logo_it_is_given" {
  command = plan

  variables {
    logo = "https://example.com/logo.svg"
  }

  assert {
    condition     = spotlight_integration.this[0].definition.logo == "https://example.com/logo.svg"
    error_message = "The integration shows the logo it is given."
  }
}
