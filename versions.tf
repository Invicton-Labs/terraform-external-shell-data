terraform {
  required_version = ">= 0.13, !=0.15.0, !=0.15.1, !=0.15.2, !=0.15.3"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 1.1.0"
    }
  }
}
