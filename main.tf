# ---------------------------------------------------------------------------
# 根模块：编排 network 与 compute 两个业务模块
#   network：4 个 VPC、9 个子网、4 个安全组、TR 及强制引流/隔离的 TR 路由。
#   compute：4 台 ECS、防火墙 ENI，及 VPC-SEC 内审计 hairpin 路由。
# ---------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  common_name      = var.common_name
  region           = var.region
  zone1            = var.zone1
  zone2            = var.zone2
  ssh_ingress_cidr = var.ssh_ingress_cidr
  tags             = var.tags
}

# 销毁时先删除 ECS、辅助 ENI 与 VPC 路由表，再等待其关联状态收敛，
# 最后进入 network 模块的安全组、子网和 TR 资源删除链。仅销毁时等待。
resource "time_sleep" "before_network_destroy" {
  destroy_duration = "30s"

  depends_on = [module.network]
}

module "compute" {
  source = "./modules/compute"

  depends_on = [time_sleep.before_network_destroy]

  common_name       = var.common_name
  zone1             = var.zone1
  instance_type     = var.instance_type
  image_id          = var.image_id
  instance_password = var.instance_password
  tags              = var.tags

  subnet_ids           = module.network.subnet_ids
  security_group_ids   = module.network.security_group_ids
  sec_vpc_id           = module.network.sec_vpc_id
  sec_fw_subnet_id     = module.network.sec_fw_subnet_id
  sec_attach_subnet_id = module.network.sec_attach_subnet_id
  transit_router_id    = module.network.transit_router_id
  prd_cidr_blocks      = module.network.prd_cidr_blocks
}
