data "spotlight_workspace" "this" {
  count = var.create ? 1 : 0

  slug = var.workspace
}

data "spotlight_team" "this" {
  count = var.create ? 1 : 0

  workspace_id = data.spotlight_workspace.this[0].id
  key          = var.team
}

locals {
  logo = coalesce(var.logo, "data:image/svg+xml;base64,${filebase64("${path.module}/logo.svg")}")

  signing_secret_name = try(spotlight_secret.signing[0].name, var.signing_secret_name)

  issue_mark      = "${var.integration}.issue"
  identifier_mark = "${var.integration}.identifier"

  on_issue = "$${{ \"${local.issue_mark}\" in task.marks ? task.marks[\"${local.issue_mark}\"] : \"\" }}"
  author   = { email = "$${{ has(body.actor) && has(body.actor.email) && body.actor.email != null ? body.actor.email : \"\" }}" }

  is_issue   = "has(body.type) && body.type == \"Issue\" && has(body.action) && has(body.data)"
  by_an_app  = "(has(body.data.botActor) && body.data.botActor != null) || (has(body.actor) && body.actor != null && has(body.actor.type) && body.actor.type == \"OauthClient\")"
  is_comment = "has(body.type) && body.type == \"Comment\" && has(body.action) && body.action == \"create\" && has(body.data) && has(body.data.issueId) && body.data.issueId != null && !(${local.by_an_app})"

  comment_mutation = "mutation CommentCreate($input: CommentCreateInput!) { commentCreate(input: $input) { success comment { id url } } }"

  comment_on = {
    method = "POST"
    url    = "https://api.linear.app/graphql"
    auth   = { oauth2 = { connection = true } }
    expect = { success = "$${{ !has(response.errors) && response.data.commentCreate.success }}" }
  }

  labelled_events = var.label == null ? [] : [
    {
      when = "$${{ ${local.is_issue} && (body.action == \"create\" || body.action == \"update\") && has(body.data.labels) && body.data.labels.exists(l, l.name.lowerAscii() == \"${lower(var.label)}\" && (body.action == \"create\" || (has(body.updatedFrom) && has(body.updatedFrom.labelIds) && !(l.id in body.updatedFrom.labelIds)))) }}"
      raise = {
        happening = "${var.integration}.issue.labelled"
        label     = "Labelled"
        summary   = "Gave the Linear issue to Spotlight."
        opens = {
          lineRole    = var.line_role
          title       = "$${{ body.data.title }}"
          description = "$${{ (has(body.data.description) && body.data.description != null ? body.data.description + \"\\n\\n\" : \"\") + body.data.url }}"
          assignBy    = local.author
        }
        marks = [
          { kind = local.issue_mark, value = "$${{ body.data.id }}" },
          { kind = local.identifier_mark, find = false, value = "$${{ body.data.identifier }}" },
        ]
      }
    },
  ]

  state_events = [
    for state in ["completed", "canceled"] : {
      when = "$${{ ${local.is_issue} && body.action == \"update\" && has(body.updatedFrom) && has(body.updatedFrom.stateId) && has(body.data.state) && body.data.state.type == \"${state}\" }}"
      raise = {
        happening = "${var.integration}.issue.${state}"
        label     = title(state)
        summary   = "Moved the Linear issue to ${title(state)}."
        marks = [
          { kind = local.issue_mark, value = "$${{ body.data.id }}" },
        ]
      }
    }
  ]

  comment_tool = merge(
    {
      action      = "comment"
      description = "Comment on a Linear issue."
      inputs = {
        issue = { type = "string", description = "The Linear issue, by its ID or its identifier, as in ENG-123. Without it, the task's issue.", default = local.on_issue }
        body  = { type = "string", required = true, stdin = true, description = "The comment, in Markdown." }
      }
      output        = "$${{ capture.url }}"
      enabledOnMark = local.issue_mark
    },
    var.comment_approval == null ? {} : { approval = { because = var.comment_approval } },
  )

  task_on = {
    "task.asked" = [{
      action = "post-comment"
      to = {
        thread = local.on_issue
        text   = "$${{ ask.body + (ask.link != null ? \"\\n\\n[Answer in Spotlight](\" + string(ask.link) + \")\" : \"\") }}"
      }
    }]
    "task.opened" = var.acknowledge ? [{
      action = "post-comment"
      to = {
        thread = local.on_issue
        text   = "$${{ \"Spotlight opened a task for this issue: [\" + task.title + \"](\" + string(task.url) + \")\" }}"
      }
    }] : []
    "task.finished" = [{
      action = "post-comment"
      to = {
        thread = local.on_issue
        text   = "$${{ \"The task “\" + task.title + \"” is complete.\" + (size(task.pullRequests) > 0 ? \" Pull requests: \" + task.pullRequests.join(\", \") : \"\") }}"
      }
    }]
  }
}

resource "spotlight_secret" "signing" {
  count = var.create && var.create_signing_secret ? 1 : 0

  workspace_id     = data.spotlight_workspace.this[0].id
  name             = var.signing_secret_name
  value_wo         = var.signing_secret
  value_wo_version = var.secret_version
}

resource "spotlight_integration" "this" {
  count = var.create ? 1 : 0

  team_id = data.spotlight_team.this[0].id
  definition = {
    integration = var.integration
    name        = var.name
    logo        = local.logo

    connection = {
      oauth2 = {
        authorize = "https://linear.app/oauth/authorize?actor=app"
        token     = "https://api.linear.app/oauth/token"
        scopes    = ["comments:create"]
      }
    }

    webhook = {
      verify = {
        hmac = {
          algorithm = "sha256"
          secret    = "secret.${local.signing_secret_name}"
          header    = "linear-signature"
          freshness = {
            at     = "$${{ string(int(body.webhookTimestamp) / 1000) }}"
            within = "60s"
          }
        }
      }
      delivery = "$${{ headers[\"linear-delivery\"] }}"
      events = concat(local.labelled_events, [
        {
          when = "$${{ ${local.is_comment} }}"
          raise = {
            happening = "${var.integration}.comment.created"
            label     = "Commented"
            summary   = "Commented on the Linear issue."
            answers   = true
            message   = "$${{ body.data.body }}"
            author    = local.author
            marks = [
              { kind = local.issue_mark, value = "$${{ body.data.issueId }}" },
            ]
          }
        },
      ], local.state_events)
    }

    actions = {
      post-comment = {
        request = merge(local.comment_on, {
          body = {
            query     = local.comment_mutation
            variables = { input = { issueId = "$${{ target.thread }}", body = "$${{ target.text }}" } }
          }
        })
      }
      comment = {
        request = merge(local.comment_on, {
          body = {
            query     = local.comment_mutation
            variables = { input = { issueId = "$${{ inputs.issue }}", body = "$${{ inputs.body }}" } }
          }
          capture = {
            url = "$${{ response.data.commentCreate.comment.url }}"
          }
        })
      }
    }

    tools = {
      comment = local.comment_tool
    }

    on = { for event, bindings in local.task_on : event => bindings if length(bindings) > 0 }
  }
}
