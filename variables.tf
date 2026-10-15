variable "region" {
  type        = string
  description = "火山引擎地域 ID，例如 cn-beijing。"
  default     = "cn-beijing"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.region))
    error_message = "region 不能为空，只能包含字母、数字、点、下划线和连字符。"
  }
}

variable "zone1" {
  type        = string
  description = "主可用区 ID，用于承载各 VPC 的主子网。"
  default     = "cn-beijing-a"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.zone1))
    error_message = "zone1 不能为空，只能包含字母、数字、点、下划线和连字符。"
  }
}

variable "zone2" {
  type        = string
  description = "备可用区 ID，用于承载各 VPC 的备子网，必须与 zone1 不同。"
  default     = "cn-beijing-b"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.zone2))
    error_message = "zone2 不能为空，只能包含字母、数字、点、下划线和连字符。"
  }
}

variable "common_name" {
  type        = string
  description = "资源名称统一前缀，便于识别与成本归类。"
  default     = "enterprise-cloud"
}

variable "instance_type" {
  type        = string
  description = "ECS 实例规格。"
  default     = "ecs.g3il.large"
}

variable "image_id" {
  type        = string
  description = "目标地域可用的 ECS 镜像 ID。"
  default     = "image-yzpyj8j5sl4e0wax4krm"

  validation {
    condition     = can(regex("^image-[A-Za-z0-9._-]+$", var.image_id))
    error_message = "image_id 必须以 image- 开头，后续只能包含字母、数字、点、下划线和连字符。"
  }
}

variable "instance_password" {
  type        = string
  description = "测试 ECS 登录密码，长度 8-30，需包含大写字母、小写字母、数字、特殊字符中的三类。"
  sensitive   = true
  default     = "ReplaceMe@12345"

  validation {
    condition = (
      length(var.instance_password) >= 8 &&
      length(var.instance_password) <= 30 &&
      length(compact([
        can(regex("[A-Z]", var.instance_password)) ? "upper" : "",
        can(regex("[a-z]", var.instance_password)) ? "lower" : "",
        can(regex("[0-9]", var.instance_password)) ? "digit" : "",
        can(regex("[^A-Za-z0-9]", var.instance_password)) ? "special" : "",
      ])) >= 3
    )
    error_message = "instance_password 长度必须为 8-30，并包含大写字母、小写字母、数字、特殊字符中的至少三类。"
  }
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "允许通过 SSH 管理测试实例的 IPv4 CIDR。"
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.ssh_ingress_cidr))
    error_message = "ssh_ingress_cidr 必须是有效的 IPv4 CIDR。"
  }
}

variable "tags" {
  type        = map(string)
  description = "统一附加到支持标签资源上的标签。"
  default = {
    project     = "enterprise-cloud-network"
    environment = "test"
    managed_by  = "terraform"
  }

  validation {
    condition     = contains(keys(var.tags), "environment") && alltrue([for value in values(var.tags) : trimspace(value) != ""])
    error_message = "tags 必须包含 environment，且所有标签值均不能为空。"
  }
}
