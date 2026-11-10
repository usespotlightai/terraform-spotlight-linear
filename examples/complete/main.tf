provider "spotlight" {
  url = var.spotlight_url
}

module "linear" {
  source = "../.."

  workspace     = "acme"
  team          = "core"
  spotlight_url = var.spotlight_url

  user_id        = var.linear_user_id
  signing_secret = var.linear_signing_secret
  api_key        = var.linear_api_key

  label     = "agent"
  line_role = "delivery"

  comment_approval = "The comment is visible to everyone in the Linear workspace."
}

module "linear_disabled" {
  source = "../.."

  create = false

  workspace = "acme"
  team      = "core"
  user_id   = var.linear_user_id
}
