terraform {
  // 0.15.0 - 0.15.3 had a bug where it threw an error if an output
  // was marked as sensitive.
  required_version = ">= 0.13.1, !=0.15.0, !=0.15.1, !=0.15.2, !=0.15.3, !=1.3.0"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 1.1.0"
    }
  }
}
