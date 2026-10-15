variable "common_name" {
  type        = string
  description = "资源名称统一前缀。"
}

variable "zone1" {
  type        = string
  description = "主可用区 ID。"
}

variable "instance_type" {
  type        = string
  description = "ECS 实例规格。"
}

variable "image_id" {
  type        = string
  description = "ECS 镜像 ID（与地域相关）。"
}

variable "instance_password" {
  type        = string
  description = "ECS 登录密码。"
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "统一标签。"
  default     = {}
}

# ---- 来自 network 模块的输入 ----
variable "subnet_ids" {
  type        = map(string)
  description = "各业务/防火墙子网 ID（prd1_z1/prd2_z1/prd3_z1/sec_fw/sec_attach）。"
}

variable "security_group_ids" {
  type        = map(string)
  description = "各 VPC 安全组 ID（prd1/prd2/prd3/sec）。"
}

variable "sec_vpc_id" {
  type        = string
  description = "安全区 VPC ID。"
}

variable "sec_fw_subnet_id" {
  type        = string
  description = "防火墙 ECS 所在子网 ID。"
}

variable "sec_attach_subnet_id" {
  type        = string
  description = "VPC-SEC 接入 TR 的连接点子网 ID。"
}

variable "transit_router_id" {
  type        = string
  description = "中转路由器 ID，作为 VPC 路由回注 TR 的下一跳。"
}

variable "prd_cidr_blocks" {
  type        = map(string)
  description = "PRD1/PRD2 业务网段，供 VPC-SEC hairpin 路由按目的网段精确引流（键：prd1/prd2）。"
}
