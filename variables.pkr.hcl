variable "skip_image" {
  type        = bool
  default     = false
  description = "Skips image generation during packer builds. Used for validation/CI."
}

variable "app_release_version" {
  type        = string
  description = "The app release version"
}

variable "appstack_version" {
  type        = string
  description = "appstack version"
}

variable "appstack_user" {
  type        = string
  description = "Username for appstack package download"
  default     = "appuser"
}

variable "appstack_pass" {
  type        = string
  description = "Password for appstack package download"
}

variable "appstack_pkg_url" {
  type        = string
  description = "appstack package download url"
  default     = ""
}

variable "git_sha" {
  type        = string
  description = "git commit sha for this build"
  default     = "manual-test-build"
}

variable "ssh_user" {
  type        = string
  description = "ssh user used by packer"
  default     = "appuser"
}

variable "ssh_password" {
  type        = string
  description = "ssh password used by packer"
  sensitive   = true
  default     = "ubuntu"
}

variable "azure_client_id" {
  type      = string
  default   = ""
  sensitive = true
}

variable "azure_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "azure_tenant_id" {
  type      = string
  default   = ""
  sensitive = true
}