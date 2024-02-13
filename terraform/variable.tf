variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default = "tarasowski"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default    = "coolapp"
}

variable "github_branch" {
  description = "GitHub repository branch"
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub OAuth token"
  type        = string
}