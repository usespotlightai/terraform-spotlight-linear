output "webhook_url" {
  description = "The URL to give the Linear webhook."
  value       = module.linear.webhook_url
}

output "tools" {
  description = "The integration's tools, by name."
  value       = module.linear.tools
}

output "happenings" {
  description = "The happenings the integration raises."
  value       = module.linear.happenings
}
