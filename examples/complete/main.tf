provider "spotlight" {
  url = var.spotlight_url
}

module "linear" {
  source = "../.."

  workspace     = "acme"
  team          = "core"
  spotlight_url = var.spotlight_url

  client_id      = var.linear_client_id
  client_secret  = var.linear_client_secret
  signing_secret = var.linear_signing_secret

  label     = "agent"
  line_role = "delivery"

  comment_approval = "The comment is visible to everyone in the Linear workspace."
}

module "linear_disabled" {
  source = "../.."

  create = false

  workspace = "acme"
  team      = "core"
}
