output "vpc_ids" {
  description = "各 VPC 的 ID。"
  value = {
    prd1 = volcenginecc_vpc_vpc.prd1.id
    prd2 = volcenginecc_vpc_vpc.prd2.id
    prd3 = volcenginecc_vpc_vpc.prd3.id
    sec  = volcenginecc_vpc_vpc.sec.id
  }
}

output "subnet_ids" {
  description = "承载业务/防火墙 ECS 的子网 ID。"
  value = {
    prd1_z1    = volcenginecc_vpc_subnet.prd1_z1.id
    prd2_z1    = volcenginecc_vpc_subnet.prd2_z1.id
    prd3_z1    = volcenginecc_vpc_subnet.prd3_z1.id
    sec_fw     = volcenginecc_vpc_subnet.sec_fw.id
    sec_attach = volcenginecc_vpc_subnet.sec_attach.id
  }
}

output "security_group_ids" {
  description = "各 VPC 的安全组 ID。"
  value = {
    prd1 = volcenginecc_vpc_security_group.prd1.id
    prd2 = volcenginecc_vpc_security_group.prd2.id
    prd3 = volcenginecc_vpc_security_group.prd3.id
    sec  = volcenginecc_vpc_security_group.sec.id
  }
}

output "sec_vpc_id" {
  description = "安全区 VPC 的 ID，供 compute 模块创建 hairpin 路由表使用。"
  value       = volcenginecc_vpc_vpc.sec.id
}

output "sec_fw_subnet_id" {
  description = "防火墙 ECS 所在子网 ID。"
  value       = volcenginecc_vpc_subnet.sec_fw.id
}

output "sec_attach_subnet_id" {
  description = "VPC-SEC 接入 TR 的连接点子网 ID，需将该子网关联到 hairpin 路由表以回注 TR。"
  value       = volcenginecc_vpc_subnet.sec_attach.id
}

output "sec_transit_router_attachment_id" {
  description = "VPC-SEC 的 TR 连接 ID，作为 hairpin 路由表回注 TR 的下一跳。"
  value       = volcenginecc_transitrouter_vpc_attachment.sec.transit_router_attachment_id
}

output "transit_router_id" {
  description = "中转路由器 ID。"
  value       = volcenginecc_transitrouter_transit_router.main.transit_router_id
}

output "prd_cidr_blocks" {
  description = "PRD1/PRD2 业务网段，供 VPC-SEC hairpin 路由按目的网段精确引流。"
  value = {
    prd1 = volcenginecc_vpc_vpc.prd1.cidr_block
    prd2 = volcenginecc_vpc_vpc.prd2.cidr_block
  }
}
