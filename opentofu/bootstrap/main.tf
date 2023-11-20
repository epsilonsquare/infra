variable "project_name" {}

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source = "registry.terraform.io/hashicorp/google"
      version = "5.7.0"
    }
  }
}

provider "google" {
  region = "europe-west1"
  zone   = "europe-west1-d"
}

resource "google_kms_key_ring" "opentofu_state" {
  name     = "eu-opentofu-state"
  location = "europe-west1"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "opentofu_state" {
  name     = "opentofu-state"
  key_ring = "projects/${var.project_name}/locations/europe-west1/keyRings/eu-opentofu-state"

  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "10000000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket" "opentofu_state" {
  name     = "${var.project_name}-opentofu-state"
  location = "EUROPE-WEST1"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.opentofu_state.id
  }
}

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_kms_crypto_key_iam_member" "opentofu_state" {
  crypto_key_id = google_kms_crypto_key.opentofu_state.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}
