# =========================================================
# ServiceMonitor(백엔드 메트릭 수집) + PrometheusRule(알림 규칙)
# 둘 다 Prometheus Operator CRD라서 kubectl provider로 적용
# =========================================================

resource "kubectl_manifest" "backend_servicemonitor" {
  yaml_body = file("${path.module}/manifests/03-springboot-servicemonitor.yaml")

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubectl_manifest" "campus_navi_alerts" {
  yaml_body = file("${path.module}/manifests/06-alerting-rules.yaml")

  depends_on = [helm_release.kube_prometheus_stack]
}
