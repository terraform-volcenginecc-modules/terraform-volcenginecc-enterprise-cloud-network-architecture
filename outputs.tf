output "vpc_ids" {
  description = "各 VPC ID。"
  value       = module.network.vpc_ids
}

output "transit_router_id" {
  description = "中转路由器 ID。"
  value       = module.network.transit_router_id
}

output "app_instance_ids" {
  description = "业务 ECS 实例 ID。"
  value       = module.compute.app_instance_ids
}

output "firewall_instance_id" {
  description = "防火墙 ECS 实例 ID（需人工开启 IP 转发）。"
  value       = module.compute.firewall_instance_id
}

# 私网 IP 输出：额外验证（PRD1<->PRD2 互通、PRD3 隔离、断路验证）的探测目标。
output "app_private_ips" {
  description = "业务 ECS（APP001/002/003）私网 IP，用于连通性与隔离验证。"
  value       = module.compute.app_private_ips
}

output "firewall_private_ip" {
  description = "防火墙 ECS（VPC-SEC）主网卡私网 IP。"
  value       = module.compute.firewall_private_ip
}

output "firewall_eni_private_ip" {
  description = "防火墙辅助网卡私网 IP，hairpin 路由表的下一跳。"
  value       = module.compute.firewall_eni_private_ip
}
