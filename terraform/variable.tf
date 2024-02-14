variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "tarasowski"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "coolapp"
}

variable "github_branch" {
  description = "GitHub repository branch"
  type        = string
  default     = "main"
}