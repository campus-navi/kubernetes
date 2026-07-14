# =========================================================
# EBS CSI Driver addon + IRSA
# (이거 없이 노드 role에 EBS 권한 주는 건 최소권한 원칙 위반이라 하지 않음 —
#  대화 초반에 직접 겪었던 IRSA 실수를 그대로 코드화해서 재발 방지)
# =========================================================

data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# 클러스터 생성 시 이미 OIDC 프로바이더가 연결되어 있다면 이 리소스 대신
# data "aws_iam_openid_connect_provider"로 대체할 것 (중복 생성 에러 방지)
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    # eksctl이 원래 만들었던 신뢰정책에 있던 조건. 토큰의 audience가
    # sts.amazonaws.com인지도 같이 검증해야 더 안전함 (빠뜨리면 검증이 약해짐)
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "AmazonEKS_EBS_CSI_DriverRole"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  # 기본값(controller 2 replica, 각 1312Mi limit)이 작은 노드에서
  # 메모리 압박을 일으켰던 실제 장애를 겪은 뒤 줄인 값
  configuration_values = jsonencode({
    controller = {
      replicaCount = 1
      resources = {
        requests = { cpu = "20m", memory = "64Mi" }
        limits   = { cpu = "100m", memory = "256Mi" }
      }
    }
  })

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_iam_role_policy_attachment.ebs_csi_driver]
}

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
  }
  storage_provisioner     = "ebs.csi.aws.com"
  volume_binding_mode     = "WaitForFirstConsumer"
  reclaim_policy          = "Delete"
  allow_volume_expansion  = true # addon이 자동 생성한 실제 StorageClass와 동일하게 명시
  parameters = {
    type = "gp3"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}