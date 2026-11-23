variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "cluster_name" {
  description = "Also used as the prefix for the VPC and IAM roles."
  type        = string
  default     = "ecommerce"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Must be one AWS currently supports: aws eks describe-cluster-versions"
  type        = string
  default     = "1.37"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

# ---------- Nodes ----------

variable "node_instance_type" {
  description = "x86 to match the linux/amd64 images built by scripts/push-images.sh. t3.medium fits 17 pods."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_disk_size_gb" {
  type    = number
  default = 20
}

# ---------- Access ----------

variable "cluster_endpoint_public_access_cidrs" {
  description = "Who may reach the Kubernetes API (kubectl). Narrow to your IP, e.g. [\"203.0.113.7/32\"]."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------- Add-on versions ----------

variable "lb_controller_chart_version" {
  description = "aws-load-balancer-controller Helm chart. When changing it, also replace policies/aws-load-balancer-controller-v<version>.json with that release's docs/install/iam_policy.json."
  type        = string
  default     = "3.6.3"
}
