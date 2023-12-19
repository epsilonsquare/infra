terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source = "registry.terraform.io/hashicorp/google"
      version = "5.7.0"
    }

    wireguard = {
      source = "registry.terraform.io/OJFord/wireguard"
      version = "0.2.2"
    }
  }

  backend "gcs" {
    bucket = "epsilonsquare-production-opentofu-state"
    prefix = "infra-production"
  }
}

provider "google" {
  project = var.project_name
  region = var.region
  zone = var.zone
}
