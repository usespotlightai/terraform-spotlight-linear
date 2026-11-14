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

variable "logo" {
  description = "The mark the web app shows for the integration, as a base64 data URI of an SVG, PNG, WebP or JPEG image or as an https address. By default, the mark of Linear."
  type        = string
  default     = null
}

variable "spotlight_url" {
  description = "The address of your Spotlight, used only for the `webhook_url` and `callback_url` outputs. Change it for a self-hosted Spotlight."
  type        = string
  default     = "https://app.usespotlight.ai"
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

variable "create_signing_secret" {
  description = "Whether the module creates the secret that holds `signing_secret`. False uses the workspace secret named `signing_secret_name`, which you keep yourself."
  type        = bool
  default     = true
}

variable "signing_secret" {
  description = "The signing secret of the Linear webhook. Needed when `create_signing_secret` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = !var.create_signing_secret || var.signing_secret != null
    error_message = "Give signing_secret, or set create_signing_secret to false."
  }
}


variable "client_id" {
  description = "The client ID of your own Linear OAuth app, which Spotlight connects the team through. Null uses the OAuth app that the Spotlight deployment keeps for Linear."
  type        = string
  default     = null
}

variable "create_client_secret" {
  description = "Whether the module creates the secret that holds `client_secret`. False uses the workspace secret named `client_secret_name`, which you keep yourself, bound to `api.linear.app`. Used only with `client_id`."
  type        = bool
  default     = true
}

variable "client_secret" {
  description = "The client secret of your own Linear OAuth app. Needed with `client_id` when `create_client_secret` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = !var.create || var.client_id == null || !var.create_client_secret || var.client_secret != null
    error_message = "Give client_secret with client_id, or set create_client_secret to false."
  }
}

variable "client_secret_name" {
  description = "The name of the workspace secret that holds the client secret."
  type        = string
  default     = "LINEAR_CLIENT_SECRET"
}

variable "secret_version" {
  description = "Change it when `signing_secret` or `client_secret` changes, so Terraform sends the new value to Spotlight."
  type        = number
  default     = 1
}

variable "signing_secret_name" {
  description = "The name of the workspace secret that holds the signing secret."
  type        = string
  default     = "LINEAR_SIGNING_SECRET"
}
