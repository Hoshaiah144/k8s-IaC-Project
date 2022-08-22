# 
#  Set Variables for resources to consume
# 
variable "aws_region" {
  default = "us-east-1"
}

variable "cluster-name" {
  default = "terraform-eks-project"
  type    = string
}