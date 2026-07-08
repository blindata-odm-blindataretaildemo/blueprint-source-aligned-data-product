# Primary GCP resources shared by the ingest job: shared labels and the resolved Artifact Registry
# image URI. Purpose: host the container image reference that Cloud Run will use at runtime.
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  default_labels = merge(
    {
      data_product = var.data_product_name
      environment  = var.environment
      managed_by   = "terraform"
    },
    var.labels
  )

  image_uri = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/${var.artifact_registry_repository}/${var.image_name}:${var.image_tag}"
}
