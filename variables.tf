variable "create" {
  description = "Whether to create the integration and its secrets. False creates nothing."
  type        = bool
  default     = true
}

variable "workspace" {
  description = "The slug of the Spotlight workspace, as in `acme`."
  type        = string
}

variable "team" {
  description = "The key of the team the integration belongs to, as in `core`."
  type        = string
}

variable "integration" {
  description = "The integration's name in the team. It is the last part of the webhook address, and the first part of every happening and mark kind the integration raises, as in `linear.issue`. Fixed for the integration's life."
  type        = string
  default     = "linear"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.integration)) && var.integration != "catalog"
    error_message = "integration is one word of lowercase letters and digits, and not catalog."
  }
}

variable "name" {
  description = "What the integration is called in the web app."
  type        = string
  default     = "Linear"
}

variable "spotlight_url" {
  description = "The address of your Spotlight, used only for the `webhook_url` output. Change it for a self-hosted Spotlight."
  type        = string
  default     = "https://app.usespotlight.ai"
}

variable "user_id" {
  description = "The ID of the Linear user that owns `api_key`. Spotlight ignores what this user does in Linear, so its own comments never answer a question or open a task."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.user_id))
    error_message = "user_id is a Linear user ID, a UUID as in 2c5e3b4a-1f0d-4e6b-9a7c-8d2e1f3a4b5c."
  }
}

variable "label" {
  description = "The name of the Linear label that gives an issue to Spotlight, compared without case. An issue that gets the label opens a task. Null opens no task from Linear."
  type        = string
  default     = "spotlight"

  validation {
    condition     = var.label == null || can(regex("^[^\"\\\\]*[^\"\\\\\\s][^\"\\\\]*$", var.label))
    error_message = "label is a label name without quotes or backslashes, or null."
  }
}

variable "line_role" {
  description = "The role of the line that an issue with `label` opens a task on, as in `delivery`."
  type        = string
  default     = "delivery"

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.line_role))
    error_message = "line_role is lowercase words joined by dashes, as in delivery."
  }
}

variable "acknowledge" {
  description = "Whether Spotlight comments on an issue, with a link to the task, when the issue opens a task."
  type        = bool
  default     = true
}

variable "comment_approval" {
  description = "When set, each use of the `comment` tool first asks a person, who is shown this text. Null lets agents and hooks comment without asking."
  type        = string
  default     = null
}

variable "create_secrets" {
  description = "Whether the module creates the two secrets from `signing_secret` and `api_key`. False uses the workspace secrets named `signing_secret_name` and `api_key_name`, which you keep yourself; the API key's secret must then be bound to `api.linear.app` in the `authorization` header, with no prefix."
  type        = bool
  default     = true
}

variable "signing_secret" {
  description = "The signing secret of the Linear webhook. Needed when `create_secrets` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "api_key" {
  description = "A Linear API key (`lin_api_`) of the user `user_id`. Needed when `create_secrets` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = !var.create_secrets || (var.signing_secret != null && var.api_key != null)
    error_message = "Give signing_secret and api_key, or set create_secrets to false."
  }
}

variable "secret_version" {
  description = "Change it when `signing_secret` or `api_key` changes, so Terraform sends the new values to Spotlight."
  type        = number
  default     = 1
}

variable "signing_secret_name" {
  description = "The name of the workspace secret that holds the signing secret."
  type        = string
  default     = "LINEAR_SIGNING_SECRET"
}

variable "api_key_name" {
  description = "The name of the workspace secret that holds the API key."
  type        = string
  default     = "LINEAR_API_KEY"
}
