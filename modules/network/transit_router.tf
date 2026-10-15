# ---------------------------------------------------------------------------
# 中转路由器 TR 与 VPC 连接
# 说明：火山引擎 TR 为独立资源，无需像阿里云 CEN 那样先建云企业网实例。
#       每个 VPC 通过 vpc_attachment 接入 TR，连接点使用双可用区子网冗余。
#       auto_publish_route_enabled=true 使 TR 路由表中的路由自动回注到 VPC，
#       从而让 VPC 内实例可将跨 VPC 流量导向 TR。
# ---------------------------------------------------------------------------

resource "volcenginecc_transitrouter_transit_router" "main" {
  transit_router_name = "${var.common_name}-tr"
  description         = "Enterprise cloud network transit router"
  tags                = local.tag_set
}

# ============ VPC-PRD1 接入 TR ============
resource "volcenginecc_transitrouter_vpc_attachment" "prd1" {
  depends_on = [volcenginecc_vpc_security_group.prd1]

  transit_router_id              = volcenginecc_transitrouter_transit_router.main.transit_router_id
  vpc_id                         = volcenginecc_vpc_vpc.prd1.id
  transit_router_attachment_name = "${var.common_name}-attach-prd1"
  auto_publish_route_enabled     = true

  attach_points = [
    {
      subnet_id = volcenginecc_vpc_subnet.prd1_z1.id
      zone_id   = var.zone1
    },
    {
      subnet_id = volcenginecc_vpc_subnet.prd1_z2.id
      zone_id   = var.zone2
    }
  ]

  tags = local.tag_set
}

# 销毁时在 PRD2 Attachment 删除后、PRD1 删除前等待 TR 状态收敛。
resource "time_sleep" "after_prd1_attachment" {
  destroy_duration = "10s"

  depends_on = [volcenginecc_transitrouter_vpc_attachment.prd1]
}

# ============ VPC-PRD2 接入 TR ============
resource "volcenginecc_transitrouter_vpc_attachment" "prd2" {
  depends_on = [
    time_sleep.after_prd1_attachment,
    volcenginecc_vpc_security_group.prd2,
  ]

  transit_router_id              = volcenginecc_transitrouter_transit_router.main.transit_router_id
  vpc_id                         = volcenginecc_vpc_vpc.prd2.id
  transit_router_attachment_name = "${var.common_name}-attach-prd2"
  auto_publish_route_enabled     = true

  attach_points = [
    {
      subnet_id = volcenginecc_vpc_subnet.prd2_z1.id
      zone_id   = var.zone1
    },
    {
      subnet_id = volcenginecc_vpc_subnet.prd2_z2.id
      zone_id   = var.zone2
    }
  ]

  tags = local.tag_set
}

# 销毁时在 SEC Attachment 删除后、PRD2 删除前等待 TR 状态收敛。
resource "time_sleep" "after_prd2_attachment" {
  destroy_duration = "10s"

  depends_on = [volcenginecc_transitrouter_vpc_attachment.prd2]
}

# ============ VPC-PRD3 接入 TR（隔离：不关联/不传播到自定义路由表） ============
# 说明：PRD3 仍建立 attachment 以便未来扩展，但不会关联或向自定义 TR 路由表
#       传播路由，因此 TR 上不存在指向 PRD3 的路由，PRD3 与其他 VPC 无法互通。
resource "volcenginecc_transitrouter_vpc_attachment" "prd3" {
  depends_on = [
    time_sleep.after_sec_attachment,
    volcenginecc_vpc_security_group.prd3,
  ]

  transit_router_id              = volcenginecc_transitrouter_transit_router.main.transit_router_id
  vpc_id                         = volcenginecc_vpc_vpc.prd3.id
  transit_router_attachment_name = "${var.common_name}-attach-prd3"
  auto_publish_route_enabled     = false

  attach_points = [
    {
      subnet_id = volcenginecc_vpc_subnet.prd3_z1.id
      zone_id   = var.zone1
    },
    {
      subnet_id = volcenginecc_vpc_subnet.prd3_z2.id
      zone_id   = var.zone2
    }
  ]

  tags = local.tag_set
}

# ============ VPC-SEC 接入 TR（承担强制引流的下一跳） ============
resource "volcenginecc_transitrouter_vpc_attachment" "sec" {
  depends_on = [
    time_sleep.after_prd2_attachment,
    volcenginecc_vpc_security_group.sec,
  ]

  transit_router_id              = volcenginecc_transitrouter_transit_router.main.transit_router_id
  vpc_id                         = volcenginecc_vpc_vpc.sec.id
  transit_router_attachment_name = "${var.common_name}-attach-sec"
  # 对齐官方「安全互访」：VPC-SEC 仅作引流，不开启路由同步，
  # 避免把 set 表路由自动下发回 SEC VPC 与手动 hairpin 路由冲突。
  auto_publish_route_enabled = false

  attach_points = [
    {
      subnet_id = volcenginecc_vpc_subnet.sec_attach.id
      zone_id   = var.zone1
    },
    {
      subnet_id = volcenginecc_vpc_subnet.sec_z2.id
      zone_id   = var.zone2
    }
  ]

  tags = local.tag_set
}

# 销毁时在 PRD3 Attachment 删除后、SEC 删除前等待 TR 状态收敛。
resource "time_sleep" "after_sec_attachment" {
  destroy_duration = "10s"

  depends_on = [volcenginecc_transitrouter_vpc_attachment.sec]
}

# TR 路由表删除后等待 10 秒，再开始反向删除 Attachment 链。
resource "time_sleep" "after_attachments" {
  destroy_duration = "10s"

  depends_on = [
    volcenginecc_transitrouter_vpc_attachment.prd1,
    volcenginecc_transitrouter_vpc_attachment.prd2,
    volcenginecc_transitrouter_vpc_attachment.sec,
    volcenginecc_transitrouter_vpc_attachment.prd3,
  ]
}
