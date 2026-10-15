variable "common_name" {
  type        = string
  description = "资源名称统一前缀。"
}

variable "region" {
  type        = string
  description = "部署地域 ID，用于校验可用区归属。"
}

variable "zone1" {
  type        = string
  description = "主可用区 ID。"
}

variable "zone2" {
  type        = string
  description = "备可用区 ID，必须与 zone1 不同。"
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "允许通过 SSH 管理测试实例的 IPv4 CIDR。"

  validation {
    condition     = can(cidrnetmask(var.ssh_ingress_cidr))
    error_message = "ssh_ingress_cidr 必须是有效的 IPv4 CIDR。"
  }
}

variable "tags" {
  type        = map(string)
  description = "统一标签。"
  default     = {}
}
