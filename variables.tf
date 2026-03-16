variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "k8s-dev"
}

variable "region" {
  description = "DO region slug"
  type        = string
  default     = "fra1"
}

variable "k8s_version" {
  description = "Kubernetes version slug (doctl kubernetes options versions)"
  type        = string
  default     = "1.31.1-do.4"
}

variable "chaos_mesh_version" {
  description = "Chaos Mesh helm chart version"
  type        = string
  default     = "2.6.3"
}

variable "trivy_version" {
  description = "Trivy operator helm chart version"
  type        = string
  default     = "0.21.4"
}

# NodePorts — диапазон 30000-32767
variable "nodeport_chaos_mesh" {
  description = "NodePort for Chaos Mesh dashboard"
  type        = number
  default     = 32333
}

variable "nodeport_goldilocks" {
  description = "NodePort for Goldilocks dashboard"
  type        = number
  default     = 32080
}
