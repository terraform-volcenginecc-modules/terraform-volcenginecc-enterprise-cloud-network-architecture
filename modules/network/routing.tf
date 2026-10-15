# ---------------------------------------------------------------------------
# TR 路由：按火山官方「实现不同 VPC 之间的安全互访」最佳实践配置
# 参考：https://docs.volcengine.com/docs/TransitRouter/ImplementingsecuremutualaccessbetweendifferentVPCs
#
# 机制（东西向流量强制经 VPC-SEC 的防火墙 ECS 审计）：
#   - 两张 TR 路由表：
#     1. sys 表（PRD1/PRD2 关联转发）：静态路由把去往 PRD1/PRD2 的流量下一跳指向
#        SEC 连接(attach-sec)，使 PRD1<->PRD2 的互访流量先被送入 VPC-SEC。
#     2. set 表（SEC 关联转发）：通过路由学习(传播)自动获得 PRD1/PRD2 网段，
#        下一跳分别为 attach-prd1 / attach-prd2，用于防火墙审计后把流量送达目的 PRD。
#   - 配合 VPC-SEC 内两张 VPC 路由表（见 compute 模块）完成 hairpin：
#     连接点子网 -> 防火墙 ENI；防火墙子网 -> TR。
#   - PRD3 不关联任何 TR 路由表、不传播，TR 上无 PRD3 路由，实现隔离。
#   - 全程无 PRD1<->PRD2 直达路由，杜绝绕过 VPC-SEC 的旁路。
# ---------------------------------------------------------------------------

# ============ sys 表：PRD1/PRD2 的出向，强制引流至 VPC-SEC ============
resource "volcenginecc_transitrouter_transit_router_route_table" "sys" {
  transit_router_id               = volcenginecc_transitrouter_transit_router.main.transit_router_id
  transit_router_route_table_name = "${var.common_name}-tr-rt-sys"
  description                     = "PRD ingress table forcing east-west traffic to VPC-SEC"
  tags                            = local.tag_set

  depends_on = [time_sleep.after_attachments]
}

# ============ set 表：VPC-SEC 的出向，审计后把流量送达目的 PRD ============
resource "volcenginecc_transitrouter_transit_router_route_table" "set" {
  transit_router_id               = volcenginecc_transitrouter_transit_router.main.transit_router_id
  transit_router_route_table_name = "${var.common_name}-tr-rt-set"
  description                     = "SEC egress table delivering audited traffic to destination PRD"
  tags                            = local.tag_set

  depends_on = [volcenginecc_transitrouter_transit_router_route_table.sys]
}

# 关联、传播和静态路由删除后等待 10 秒，再删除两张 TR 路由表。
resource "time_sleep" "after_tr_route_tables" {
  destroy_duration = "10s"

  depends_on = [volcenginecc_transitrouter_transit_router_route_table.set]
}

# ---- 关联转发：PRD1 / PRD2 使用 sys 表 ----
resource "volcenginecc_transitrouter_transit_router_route_table_association" "prd1" {
  transit_router_attachment_id  = volcenginecc_transitrouter_vpc_attachment.prd1.transit_router_attachment_id
  transit_router_route_table_id = volcenginecc_transitrouter_transit_router_route_table.sys.transit_router_route_table_id

  depends_on = [time_sleep.after_tr_route_tables]
}

resource "volcenginecc_transitrouter_transit_router_route_table_association" "prd2" {
  depends_on = [volcenginecc_transitrouter_transit_router_route_table_association.prd1]

  transit_router_attachment_id  = volcenginecc_transitrouter_vpc_attachment.prd2.transit_router_attachment_id
  transit_router_route_table_id = volcenginecc_transitrouter_transit_router_route_table.sys.transit_router_route_table_id
}

# ---- 关联转发：SEC 使用 set 表 ----
resource "volcenginecc_transitrouter_transit_router_route_table_association" "sec" {
  depends_on = [volcenginecc_transitrouter_transit_router_route_table_association.prd2]

  transit_router_attachment_id  = volcenginecc_transitrouter_vpc_attachment.sec.transit_router_attachment_id
  transit_router_route_table_id = volcenginecc_transitrouter_transit_router_route_table.set.transit_router_route_table_id
}

# ---- 路由学习（传播）：PRD1 / PRD2 的网段学习进 set 表 ----
# 使 set 表自动生成 PRD1网段->attach-prd1、PRD2网段->attach-prd2，
# 供 VPC-SEC 防火墙审计后把流量正确送达目的 PRD。
resource "volcenginecc_transitrouter_route_table_propagation" "prd1_to_set" {
  depends_on = [volcenginecc_transitrouter_transit_router_route_table_association.sec]

  transit_router_attachment_id  = volcenginecc_transitrouter_vpc_attachment.prd1.transit_router_attachment_id
  transit_router_route_table_id = volcenginecc_transitrouter_transit_router_route_table.set.transit_router_route_table_id
}

resource "volcenginecc_transitrouter_route_table_propagation" "prd2_to_set" {
  depends_on = [volcenginecc_transitrouter_route_table_propagation.prd1_to_set]

  transit_router_attachment_id  = volcenginecc_transitrouter_vpc_attachment.prd2.transit_router_attachment_id
  transit_router_route_table_id = volcenginecc_transitrouter_transit_router_route_table.set.transit_router_route_table_id
}

# ---- sys 表静态路由：PRD1/PRD2 的互访流量强制下一跳指向 VPC-SEC ----
resource "volcenginecc_transitrouter_transit_router_route_entry" "sys_to_sec_prd1" {
  transit_router_route_table_id            = volcenginecc_transitrouter_transit_router_route_table.sys.transit_router_route_table_id
  destination_cidr_block                   = volcenginecc_vpc_vpc.prd1.cidr_block
  transit_router_route_entry_next_hop_type = "Attachment"
  transit_router_route_entry_next_hop_id   = volcenginecc_transitrouter_vpc_attachment.sec.transit_router_attachment_id
  transit_router_route_entry_name          = "${var.common_name}-sys-prd1-to-sec"

  depends_on = [volcenginecc_transitrouter_route_table_propagation.prd2_to_set]
}

resource "volcenginecc_transitrouter_transit_router_route_entry" "sys_to_sec_prd2" {
  transit_router_route_table_id            = volcenginecc_transitrouter_transit_router_route_table.sys.transit_router_route_table_id
  destination_cidr_block                   = volcenginecc_vpc_vpc.prd2.cidr_block
  transit_router_route_entry_next_hop_type = "Attachment"
  transit_router_route_entry_next_hop_id   = volcenginecc_transitrouter_vpc_attachment.sec.transit_router_attachment_id
  transit_router_route_entry_name          = "${var.common_name}-sys-prd2-to-sec"

  depends_on = [volcenginecc_transitrouter_transit_router_route_entry.sys_to_sec_prd1]
}
