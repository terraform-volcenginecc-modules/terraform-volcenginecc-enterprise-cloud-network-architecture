# ---------------------------------------------------------------------------
# compute 模块：业务/防火墙 ECS，及 VPC-SEC 内的审计 hairpin 路由
# 职责：
#   1. APP001/002/003 分别位于 PRD1/PRD2/PRD3，模拟业务实例。
#   2. SEC001 位于 VPC-SEC，作为模拟防火墙（需人工开启 IP 转发，见 README）。
#   3. SEC001 挂载一块辅助 ENI，关闭源目地址校验以支持转发。
#   4. VPC-SEC 内两张自定义路由表实现审计 hairpin：
#      - 连接点子网(sec_attach)：0.0.0.0/0 -> 防火墙 ENI（把 TR 来的流量交给防火墙）
#      - 防火墙子网(sec_fw)     ：0.0.0.0/0 -> SEC 的 TR 连接（审计后回注 TR）
# ---------------------------------------------------------------------------

locals {
  tag_set = [for k, v in var.tags : { key = k, value = v }]
}

# ============ 业务 ECS ============
resource "volcenginecc_ecs_instance" "app001" {
  instance_name = "${var.common_name}-APP001"
  instance_type = var.instance_type
  password      = var.instance_password
  zone_id       = var.zone1

  image = {
    image_id = var.image_id
  }

  primary_network_interface = {
    subnet_id          = var.subnet_ids["prd1_z1"]
    security_group_ids = [var.security_group_ids["prd1"]]
  }

  system_volume = {
    volume_type          = "ESSD_PL0"
    size                 = 40
    delete_with_instance = true
  }

  tags = local.tag_set
}

resource "volcenginecc_ecs_instance" "app002" {
  instance_name = "${var.common_name}-APP002"
  instance_type = var.instance_type
  password      = var.instance_password
  zone_id       = var.zone1

  image = {
    image_id = var.image_id
  }

  primary_network_interface = {
    subnet_id          = var.subnet_ids["prd2_z1"]
    security_group_ids = [var.security_group_ids["prd2"]]
  }

  system_volume = {
    volume_type          = "ESSD_PL0"
    size                 = 40
    delete_with_instance = true
  }

  tags = local.tag_set
}

resource "volcenginecc_ecs_instance" "app003" {
  instance_name = "${var.common_name}-APP003"
  instance_type = var.instance_type
  password      = var.instance_password
  zone_id       = var.zone1

  image = {
    image_id = var.image_id
  }

  primary_network_interface = {
    subnet_id          = var.subnet_ids["prd3_z1"]
    security_group_ids = [var.security_group_ids["prd3"]]
  }

  system_volume = {
    volume_type          = "ESSD_PL0"
    size                 = 40
    delete_with_instance = true
  }

  tags = local.tag_set
}

# ============ 防火墙 ECS（模拟，需人工开启 IP 转发） ============
resource "volcenginecc_ecs_instance" "sec001" {
  instance_name = "${var.common_name}-SEC001"
  instance_type = var.instance_type
  password      = var.instance_password
  zone_id       = var.zone1

  image = {
    image_id = var.image_id
  }

  primary_network_interface = {
    subnet_id          = var.sec_fw_subnet_id
    security_group_ids = [var.security_group_ids["sec"]]
  }

  system_volume = {
    volume_type          = "ESSD_PL0"
    size                 = 40
    delete_with_instance = true
  }

  tags = local.tag_set
}

# 防火墙辅助网卡：关闭源目地址校验，允许转发非本机地址流量
resource "volcenginecc_vpc_eni" "sec_fw" {
  subnet_id              = var.sec_fw_subnet_id
  security_group_ids     = [var.security_group_ids["sec"]]
  network_interface_name = "${var.common_name}-eni-sec"
  instance_id            = volcenginecc_ecs_instance.sec001.instance_id
  port_security_enabled  = false
  tags                   = local.tag_set
}

# ============ VPC-SEC 审计 hairpin 路由（对齐官方「安全互访」最佳实践） ============
# 连接点子网(sec_attach，TR 服务网卡所在子网)路由表：
#   去往 PRD1/PRD2 的流量下一跳指向防火墙 ENI，把 TR 送入的流量交给防火墙 ECS 审计。
#   按目的网段精确配置（而非 0.0.0.0/0），避免影响 VPC-SEC 自身其它流量。
resource "volcenginecc_vpc_route_table" "sec_ingress" {
  vpc_id           = var.sec_vpc_id
  route_table_name = "${var.common_name}-rt-sec-ingress"
  description      = "Route TR-ingress traffic to firewall ENI for audit"
  subnet_ids       = [var.sec_attach_subnet_id]

  custom_route_entries = [
    {
      destination_cidr_block = var.prd_cidr_blocks["prd1"]
      next_hop_type          = "NetworkInterface"
      next_hop_id            = volcenginecc_vpc_eni.sec_fw.network_interface_id
      route_entry_name       = "${var.common_name}-to-fw-prd1"
    },
    {
      destination_cidr_block = var.prd_cidr_blocks["prd2"]
      next_hop_type          = "NetworkInterface"
      next_hop_id            = volcenginecc_vpc_eni.sec_fw.network_interface_id
      route_entry_name       = "${var.common_name}-to-fw-prd2"
    }
  ]
}

# 防火墙子网(sec_fw，ecs-fw 所在子网)路由表：
#   审计后去往 PRD1/PRD2 的流量下一跳回注 TR，由 TR 的 set 表送达目的 PRD。
resource "volcenginecc_vpc_route_table" "sec_egress" {
  vpc_id           = var.sec_vpc_id
  route_table_name = "${var.common_name}-rt-sec-egress"
  description      = "Route audited traffic from firewall back to Transit Router"
  subnet_ids       = [var.sec_fw_subnet_id]

  custom_route_entries = [
    {
      destination_cidr_block = var.prd_cidr_blocks["prd1"]
      next_hop_type          = "TransitRouter"
      next_hop_id            = var.transit_router_id
      route_entry_name       = "${var.common_name}-back-tr-prd1"
    },
    {
      destination_cidr_block = var.prd_cidr_blocks["prd2"]
      next_hop_type          = "TransitRouter"
      next_hop_id            = var.transit_router_id
      route_entry_name       = "${var.common_name}-back-tr-prd2"
    }
  ]
}
