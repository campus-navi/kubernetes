# =========================================================
# 모니터링 전용 t3.medium NodeGroup (ng-monitoring)
# 실제로 eksctl 대신 aws eks create-nodegroup으로 만들었던 것을 그대로 반영
# =========================================================

resource "aws_eks_node_group" "monitoring" {
  cluster_name    = var.cluster_name
  node_group_name = "ng-monitoring"
  node_role_arn   = var.existing_node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"

  # 실제 운영에서는 1대로 시작 (계산상 requests/limits 합이 t3.medium 1대에
  # 충분히 들어가는 걸 확인함). 여유가 더 필요하면 desired_size를 올릴 것.
  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  labels = {
    role = "monitoring"
  }

  # 이 taint가 있어야 일반 앱 파드가 이 노드로 넘어오지 않음.
  # helm values.yaml의 tolerations와 key/value/effect가 정확히 일치해야 함.
  taint {
    key    = "dedicated"
    value  = "monitoring"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name = "${var.cluster_name}-ng-monitoring"
  }
}

output "monitoring_nodegroup_name" {
  value = aws_eks_node_group.monitoring.node_group_name
}
