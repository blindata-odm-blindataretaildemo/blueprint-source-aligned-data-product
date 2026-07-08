# Exported identifiers after apply. Purpose: surface job name and resolved image URI for scripts,
# GitHub Actions summaries, or operators wiring monitoring.
output "cloud_run_job_name" {
  description = "Cloud Run Job name."
  value       = google_cloud_run_v2_job.ingest.name
}

output "artifact_image_uri" {
  description = "Resolved container image URI used by the job."
  value       = local.image_uri
}
