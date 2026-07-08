# IAM bindings for the ingest job service account. Purpose: grant least-privilege access
# to Secret Manager (read the Oracle ERP and PostgreSQL DWH credential secrets referenced by the job).
resource "google_secret_manager_secret_iam_member" "oracle_accessor" {
  project   = var.gcp_project_id
  secret_id = local.oracle_secret_short
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ingest_job.email}"
}

resource "google_secret_manager_secret_iam_member" "postgres_dwh_accessor" {
  project   = var.gcp_project_id
  secret_id = local.postgres_dwh_secret_short
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ingest_job.email}"
}
