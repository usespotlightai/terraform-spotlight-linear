variable "spotlight_url" {
  description = "The Spotlight the integration is created in."
  type        = string
  default     = "https://app.usespotlight.ai"
}

variable "linear_user_id" {
  description = "The ID of the Linear user that owns the API key."
  type        = string
}

variable "linear_signing_secret" {
  description = "The signing secret of the Linear webhook."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "linear_api_key" {
  description = "The Linear API key."
  type        = string
  sensitive   = true
  ephemeral   = true
}
