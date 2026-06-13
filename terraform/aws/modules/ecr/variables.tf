variable "env" {
  description = "Environment name (e.g., shared, dev, staging)"
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten"
  type        = string
  default     = "MUTABLE" # or IMMUTABLE
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all ECR repositories"
  type        = map(string)
  default     = {}
}