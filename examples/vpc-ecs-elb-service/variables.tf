### Global variables:
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {
    Service   = "Full-ECS-Deployment"
    CreatedBy = "JManzur - https://jmanzur.com"
    Env       = "POC"
  }
}

variable "name_prefix" {
  type        = string
  description = "[REQUIRED] Used to name and tag resources."
  default     = "jm"
}

variable "environment" {
  type        = string
  description = "[REQUIRED] Used to name and tag resources."
  default     = "poc"
}

variable "name_suffix" {
  description = "[REQUIRED] Suffix to use for naming in global resources (e.g. `main` or `dr`)"
  type        = string
  default     = "main"
}
