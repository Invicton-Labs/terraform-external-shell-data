terraform {
  required_version = ">= 0.12"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.2.0"
    }
  }
}
