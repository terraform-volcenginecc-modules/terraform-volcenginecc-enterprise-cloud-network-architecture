output "app_instance_ids" {
  description = "业务 ECS 实例 ID。"
  value = {
    app001 = volcenginecc_ecs_instance.app001.instance_id
    app002 = volcenginecc_ecs_instance.app002.instance_id
    app003 = volcenginecc_ecs_instance.app003.instance_id
  }
}

output "firewall_instance_id" {
  description = "防火墙 ECS 实例 ID。"
  value       = volcenginecc_ecs_instance.sec001.instance_id
}

output "firewall_eni_id" {
  description = "防火墙辅助网卡 ID。"
  value       = volcenginecc_vpc_eni.sec_fw.network_interface_id
}

# 私网 IP 输出：作为 PRD1<->PRD2 互通、PRD3 隔离及断路验证的探测目标。
output "app_private_ips" {
  description = "业务 ECS 的私网 IP，用于连通性与隔离验证。"
  value = {
    app001 = volcenginecc_ecs_instance.app001.primary_network_interface.primary_ip_address
    app002 = volcenginecc_ecs_instance.app002.primary_network_interface.primary_ip_address
    app003 = volcenginecc_ecs_instance.app003.primary_network_interface.primary_ip_address
  }
}

output "firewall_private_ip" {
  description = "防火墙 ECS（VPC-SEC）主网卡私网 IP。"
  value       = volcenginecc_ecs_instance.sec001.primary_network_interface.primary_ip_address
}

output "firewall_eni_private_ip" {
  description = "防火墙辅助网卡私网 IP，为 hairpin 路由表的下一跳。"
  value       = volcenginecc_vpc_eni.sec_fw.primary_ip_address.private_ip_address
}
