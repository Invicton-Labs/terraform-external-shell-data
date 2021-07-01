terraform {
  required_version = ">= 0.12.19"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.1.0"
    }
  }
}
