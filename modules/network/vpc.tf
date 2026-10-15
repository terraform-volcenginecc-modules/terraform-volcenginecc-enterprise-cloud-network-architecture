# ---------------------------------------------------------------------------
# network 模块：企业云上网络底座
# 职责：4 个 VPC、9 个子网、4 个安全组。
# 边界：本文件只负责 VPC/子网/安全组等网络资源；TR 与路由分别在
#       transit_router.tf、routing.tf 中定义；ECS/ENI 在 compute 模块。
# ---------------------------------------------------------------------------

locals {
  # 将 map(string) 标签转换为 volcenginecc 资源要求的 nested set 结构。
  tag_set = [for k, v in var.tags : { key = k, value = v }]
}

# ============ 生产业务区 VPC-PRD1 ============
# 三个 PRD VPC 必须使用互不重叠的网段，跨 VPC 流量才会被判定为跨网段
# 而进入 TR，命中强制引流默认路由并经 VPC-SEC 审计；若网段重叠，流量会
# 在本 VPC 内直连从而绕过 SEC，导致强制引流与隔离失效。
resource "volcenginecc_vpc_vpc" "prd1" {
  vpc_name   = "${var.common_name}-VPC-PRD1"
  cidr_block = "10.1.0.0/16"
  tags       = local.tag_set

  lifecycle {
    precondition {
      condition     = startswith(var.zone1, "${var.region}-")
      error_message = "zone1 必须属于 region 指定的地域。"
    }

    precondition {
      condition     = startswith(var.zone2, "${var.region}-") && var.zone2 != var.zone1
      error_message = "zone2 必须属于 region 指定的地域，且不能与 zone1 相同。"
    }
  }
}

resource "volcenginecc_vpc_subnet" "prd1_z1" {
  vpc_id      = volcenginecc_vpc_vpc.prd1.id
  cidr_block  = "10.1.0.0/24"
  zone_id     = var.zone1
  subnet_name = "${var.common_name}-subnet-prd1-z1"
  tags        = local.tag_set
}

resource "volcenginecc_vpc_subnet" "prd1_z2" {
  vpc_id      = volcenginecc_vpc_vpc.prd1.id
  cidr_block  = "10.1.100.0/24"
  zone_id     = var.zone2
  subnet_name = "${var.common_name}-subnet-prd1-z2"
  tags        = local.tag_set
}

# ============ 生产业务区 VPC-PRD2 ============
resource "volcenginecc_vpc_vpc" "prd2" {
  vpc_name   = "${var.common_name}-VPC-PRD2"
  cidr_block = "10.2.0.0/16"
  tags       = local.tag_set
}

resource "volcenginecc_vpc_subnet" "prd2_z1" {
  vpc_id      = volcenginecc_vpc_vpc.prd2.id
  cidr_block  = "10.2.1.0/24"
  zone_id     = var.zone1
  subnet_name = "${var.common_name}-subnet-prd2-z1"
  tags        = local.tag_set
}

resource "volcenginecc_vpc_subnet" "prd2_z2" {
  vpc_id      = volcenginecc_vpc_vpc.prd2.id
  cidr_block  = "10.2.101.0/24"
  zone_id     = var.zone2
  subnet_name = "${var.common_name}-subnet-prd2-z2"
  tags        = local.tag_set
}

# ============ 独立业务区 VPC-PRD3（隔离，不与其他 VPC 互通） ============
resource "volcenginecc_vpc_vpc" "prd3" {
  vpc_name   = "${var.common_name}-VPC-PRD3"
  cidr_block = "10.3.0.0/16"
  tags       = local.tag_set
}

resource "volcenginecc_vpc_subnet" "prd3_z1" {
  vpc_id      = volcenginecc_vpc_vpc.prd3.id
  cidr_block  = "10.3.2.0/24"
  zone_id     = var.zone1
  subnet_name = "${var.common_name}-subnet-prd3-z1"
  tags        = local.tag_set
}

resource "volcenginecc_vpc_subnet" "prd3_z2" {
  vpc_id      = volcenginecc_vpc_vpc.prd3.id
  cidr_block  = "10.3.102.0/24"
  zone_id     = var.zone2
  subnet_name = "${var.common_name}-subnet-prd3-z2"
  tags        = local.tag_set
}

# ============ 安全区 VPC-SEC（承载防火墙 ECS，做流量审计） ============
resource "volcenginecc_vpc_vpc" "sec" {
  vpc_name   = "${var.common_name}-VPC-SEC"
  cidr_block = "172.16.0.0/12"
  tags       = local.tag_set
}

# TR 连接点子网（挂接到中转路由器）
resource "volcenginecc_vpc_subnet" "sec_attach" {
  vpc_id      = volcenginecc_vpc_vpc.sec.id
  cidr_block  = "172.16.0.0/25"
  zone_id     = var.zone1
  subnet_name = "${var.common_name}-subnet-sec-attach"
  tags        = local.tag_set
}

# 防火墙 ECS 业务子网（主可用区）
resource "volcenginecc_vpc_subnet" "sec_fw" {
  vpc_id      = volcenginecc_vpc_vpc.sec.id
  cidr_block  = "172.16.128.0/25"
  zone_id     = var.zone1
  subnet_name = "${var.common_name}-subnet-sec-fw"
  tags        = local.tag_set
}

# 备可用区子网（用于 TR 双可用区连接点冗余）
resource "volcenginecc_vpc_subnet" "sec_z2" {
  vpc_id      = volcenginecc_vpc_vpc.sec.id
  cidr_block  = "172.16.200.0/25"
  zone_id     = var.zone2
  subnet_name = "${var.common_name}-subnet-sec-z2"
  tags        = local.tag_set
}

# ============ 安全组（每个 VPC 一个） ============
# 说明：入方向放通同一网络平面内的私网互访，并允许指定管理网段访问 SSH。
# 出方向由云平台默认规则管理。
resource "volcenginecc_vpc_security_group" "prd1" {
  depends_on = [
    volcenginecc_vpc_subnet.prd1_z1,
    volcenginecc_vpc_subnet.prd1_z2,
  ]

  vpc_id              = volcenginecc_vpc_vpc.prd1.id
  security_group_name = "${var.common_name}-sg-prd1"
  description         = "Security group for VPC-PRD1"
  ingress_permissions = local.default_ingress
  tags                = local.tag_set

  lifecycle {
    ignore_changes = [egress_permissions]
  }
}

resource "volcenginecc_vpc_security_group" "prd2" {
  depends_on = [
    volcenginecc_vpc_subnet.prd2_z1,
    volcenginecc_vpc_subnet.prd2_z2,
  ]

  vpc_id              = volcenginecc_vpc_vpc.prd2.id
  security_group_name = "${var.common_name}-sg-prd2"
  description         = "Security group for VPC-PRD2"
  ingress_permissions = local.default_ingress
  tags                = local.tag_set

  lifecycle {
    ignore_changes = [egress_permissions]
  }
}

resource "volcenginecc_vpc_security_group" "prd3" {
  depends_on = [
    volcenginecc_vpc_subnet.prd3_z1,
    volcenginecc_vpc_subnet.prd3_z2,
  ]

  vpc_id              = volcenginecc_vpc_vpc.prd3.id
  security_group_name = "${var.common_name}-sg-prd3"
  description         = "Security group for VPC-PRD3"
  ingress_permissions = local.default_ingress
  tags                = local.tag_set

  lifecycle {
    ignore_changes = [egress_permissions]
  }
}

resource "volcenginecc_vpc_security_group" "sec" {
  depends_on = [
    volcenginecc_vpc_subnet.sec_attach,
    volcenginecc_vpc_subnet.sec_fw,
    volcenginecc_vpc_subnet.sec_z2,
  ]

  vpc_id              = volcenginecc_vpc_vpc.sec.id
  security_group_name = "${var.common_name}-sg-sec"
  description         = "Security group for VPC-SEC firewall"
  ingress_permissions = local.default_ingress
  tags                = local.tag_set

  lifecycle {
    ignore_changes = [egress_permissions]
  }
}

locals {
  # 入方向：放通三个生产网段与安全区网段之间的私网 IP 全协议互访，
  # 便于业务互通与防火墙审计转发；同时允许指定管理网段访问 22 端口。
  default_ingress = [
    {
      cidr_ip         = "10.0.0.0/8"
      protocol        = "all"
      port_start      = -1
      port_end        = -1
      policy          = "accept"
      priority        = 1
      direction       = "ingress"
      description     = "Allow intranet from PRD CIDR"
      prefix_list_id  = ""
      source_group_id = ""
    },
    {
      cidr_ip         = "172.16.0.0/12"
      protocol        = "all"
      port_start      = -1
      port_end        = -1
      policy          = "accept"
      priority        = 1
      direction       = "ingress"
      description     = "Allow intranet from SEC CIDR"
      prefix_list_id  = ""
      source_group_id = ""
    },
    {
      cidr_ip         = var.ssh_ingress_cidr
      protocol        = "tcp"
      port_start      = 22
      port_end        = 22
      policy          = "accept"
      priority        = 2
      direction       = "ingress"
      description     = "Allow SSH for management"
      prefix_list_id  = ""
      source_group_id = ""
    }
  ]
}
