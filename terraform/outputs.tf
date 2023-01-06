# After a successful terraform run, the token service URL will be output.
# This is the URL that the Looker service will need to call to request a token.
output "service_url" {
  value = google_cloud_run_service.looker_gcp_auth_service.status[0].url
}
