variable "aws_region" {
  description = "AWS region where resources will be deployed."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "bizaway-eks"
}
