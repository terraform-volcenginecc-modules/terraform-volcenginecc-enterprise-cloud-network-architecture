provider "volcenginecc" {
  # 认证凭据由环境变量提供，工程不保存 AK/SK：
  #   VOLCENGINE_ACCESS_KEY、VOLCENGINE_SECRET_KEY
  # region 也可由 VOLCENGINE_REGION 提供，这里显式参数化便于多环境复用。
  region = var.region
}
