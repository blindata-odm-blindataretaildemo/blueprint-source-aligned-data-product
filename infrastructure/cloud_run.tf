# Cloud Run Job + dedicated service account for the ingest runner. Purpose: run the
# container with Secret Manager–mounted Oracle/PostgreSQL DWH credentials and descriptor path.
locals {
  ingest_sa_account_id = substr(
    replace(lower("ing-${var.data_product_name}-${var.environment}"), "_", "-"),
    0,
    30
  )

  oracle_secret_short = (
    startswith(var.oracle_secret_id, "projects/")
    ? element(split("/", var.oracle_secret_id), 3)
    : var.oracle_secret_id
  )

  postgres_dwh_secret_short = (
    startswith(var.postgres_dwh_secret_id, "projects/")
    ? element(split("/", var.postgres_dwh_secret_id), 3)
    : var.postgres_dwh_secret_id
  )

  oracle_secret = (
    startswith(var.oracle_secret_id, "projects/")
    ? var.oracle_secret_id
    : "projects/${var.gcp_project_id}/secrets/${local.oracle_secret_short}"
  )

  postgres_dwh_secret = (
    startswith(var.postgres_dwh_secret_id, "projects/")
    ? var.postgres_dwh_secret_id
    : "projects/${var.gcp_project_id}/secrets/${local.postgres_dwh_secret_short}"
  )
}

resource "google_service_account" "ingest_job" {
  account_id   = local.ingest_sa_account_id
  display_name = "Ingest job (${var.data_product_name}, ${var.environment})"
  project      = var.gcp_project_id
}

resource "google_cloud_run_v2_job" "ingest" {
  name     = var.cloud_run_job_name
  location = var.gcp_region
  project  = var.gcp_project_id

  labels = local.default_labels

  template {
    template {
      service_account = google_service_account.ingest_job.email

      volumes {
        name = "oracle-creds"
        secret {
          secret       = local.oracle_secret
          default_mode = 420
          items {
            path    = "credentials"
            version = "latest"
          }
        }
      }

      volumes {
        name = "postgres-dwh-creds"
        secret {
          secret       = local.postgres_dwh_secret
          default_mode = 420
          items {
            path    = "credentials"
            version = "latest"
          }
        }
      }

      containers {
        image = local.image_uri

        env {
          name  = "DESCRIPTOR_PATH"
          value = var.descriptor_path
        }

        env {
          name  = "SOURCES__ORACLE__CREDENTIALS"
          value = "/secrets/oracle/credentials"
        }

        env {
          name  = "DESTINATION__POSTGRES__CREDENTIALS"
          value = "/secrets/postgres-dwh/credentials"
        }

        env {
          name  = "INGEST_CURSOR_FIELD"
          value = var.cursor_field
        }

        env {
          name  = "INGEST_ROW_DISCRIMINATOR_COLUMN"
          value = var.row_discriminator_column
        }

        volume_mounts {
          name       = "oracle-creds"
          mount_path = "/secrets/oracle"
        }

        volume_mounts {
          name       = "postgres-dwh-creds"
          mount_path = "/secrets/postgres-dwh"
        }

        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
        }
      }

      timeout     = "3600s"
      max_retries = 2
    }
  }
}
