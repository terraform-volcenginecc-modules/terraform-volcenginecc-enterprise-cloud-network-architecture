region        = "cn-beijing"
zone1         = "cn-beijing-a"
zone2         = "cn-beijing-b"
common_name   = "enterprise-cloud"
instance_type = "ecs.g3il.large"
# 镜像 ID 与地域相关，请替换为目标地域的公共镜像 ID（控制台或 DescribeImages 查询）
image_id = "image-yzpyj8j5sl4e0wax4krm"
# 测试环境默认使用 variables.tf 中的密码；需要时通过环境变量覆盖
# export TF_VAR_instance_password='YourStrongPassword#2026'

tags = {
  project     = "enterprise-cloud-network"
  environment = "test"
  managed_by  = "terraform"
}
