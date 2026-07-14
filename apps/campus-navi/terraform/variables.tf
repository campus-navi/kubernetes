# =========================================================
# 실제로 수동(eksctl/aws cli/helm)으로 구축한 모니터링 인프라를
# 그대로 반영한 Terraform 변수 정의
# =========================================================

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "cluster_name" {
  type    = string
  default = "campus-navi-cluster"
}

variable "account_id" {
  type    = string
  default = "154959837798"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "ng-monitoring을 배치할 프라이빗 서브넷 목록"
}

# 실제로는 ng-1-workers가 쓰는 기존 노드 IAM 역할을 그대로 재사용했음.
# (EBS CSI 권한은 노드 role이 아니라 IRSA에 있으므로 재사용해도 무방)
variable "existing_node_role_arn" {
  type        = string
  description = "기존 워커 노드그룹이 쓰는 IAM 역할 ARN (ng-monitoring도 재사용)"
}

variable "discord_webhook_url" {
  type        = string
  sensitive   = true
  description = "Alertmanager -> Discord 알림용 웹훅 URL. terraform.tfvars나 -var-file로 주입, git에 커밋 금지"
}

variable "grafana_admin_password" {
  type        = string
  sensitive   = true
  description = "Grafana admin 비밀번호. 마찬가지로 git에 커밋 금지"
}
