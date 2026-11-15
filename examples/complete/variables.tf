variable "spotlight_url" {
  description = "The Spotlight the integration is created in."
  type        = string
  default     = "https://app.usespotlight.ai"
}


variable "linear_signing_secret" {
  description = "The signing secret of the Linear webhook."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "linear_client_id" {
  description = "The client ID of the team's Linear OAuth app."
  type        = string
}

variable "linear_client_secret" {
  description = "The client secret of the team's Linear OAuth app."
  type        = string
  sensitive   = true
  ephemeral   = true
}
