terraform {
  required_version = ">= 0.12.19"
  required_providers {
    aws = {
      source  = "hashicorp/external"
      version = ">= 2.1.0"
    }
  }
}
