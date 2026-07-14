# =========================================================
# kube-prometheus-stack 설치 (Prometheus + Grafana + Alertmanager)
# =========================================================

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "65.5.1"

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      discord_webhook_url    = var.discord_webhook_url
      grafana_admin_password = var.grafana_admin_password
    })
  ]

  depends_on = [
    aws_eks_node_group.monitoring,
    aws_eks_addon.ebs_csi,
    kubernetes_storage_class.gp3,
  ]
}
