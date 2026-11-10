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
