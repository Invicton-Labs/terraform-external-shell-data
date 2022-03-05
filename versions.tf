terraform {
  required_version = ">= 0.13"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.1.0"
    }
  }
}
