terraform {
  required_version = ">= 0.13"
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
      version = ">= 1.60.0"
    }
  }
}

provider "ibm" {
  region = var.region
  ibmcloud_api_key = var.ibmcloud_api_key
}