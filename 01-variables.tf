variable "ibmcloud_api_key" {
  type = string
}

variable "region" {
  type = string
}
variable "resource_group_name" {
  type = string
}

variable "resource_prefix" {
  type = string
}
variable "resource_suffix" {
  type = string
}

variable "tags" {
  type = list(string)
}

variable "ubuntu_image" {
  type = string
}

variable "allowlist" {
  type = list(string)
}

variable "ssh_public_key" {
  type = string
}

