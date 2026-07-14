# =========================================================
# kube-prometheus-stack values.yaml (terraform templatefile로 렌더링됨)
# ng-monitoring 노드(label: role=monitoring, taint: dedicated=monitoring:NoSchedule)
# 에만 스케줄되도록 설정. 대화 중 실제로 겪은 문제들 반영:
#  - defaultRules.create=false 안 하면 Watchdog 등 ~50개 기본 알림이 Discord로 쏟아짐
#  - alertmanager.config에서 receivers 리스트 교체 시 'null' receiver도 같이 남겨야 함
#  - kubeControllerManager/Scheduler/Etcd는 EKS에서 접근 불가라 꺼야 함
# =========================================================

defaultRules:
  create: false

commonNodeSelector: &nodeSelector
  role: monitoring

commonTolerations: &tolerations
  - key: "dedicated"
    operator: "Equal"
    value: "monitoring"
    effect: "NoSchedule"

prometheus:
  prometheusSpec:
    nodeSelector: *nodeSelector
    tolerations: *tolerations

    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

    retention: 15d

    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi

    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1.5Gi

alertmanager:
  alertmanagerSpec:
    nodeSelector: *nodeSelector
    tolerations: *tolerations
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 5Gi

  config:
    route:
      receiver: "discord"
      group_by: ["alertname", "namespace"]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 3h
      routes: []
    receivers:
      - name: "discord"
        discord_configs:
          - webhook_url: "${discord_webhook_url}"
            send_resolved: true
      - name: "null"

grafana:
  nodeSelector: *nodeSelector
  tolerations: *tolerations

  adminPassword: "${grafana_admin_password}"

  persistence:
    enabled: true
    storageClassName: gp3
    size: 5Gi

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

kube-state-metrics:
  nodeSelector: *nodeSelector
  tolerations: *tolerations
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi

prometheusOperator:
  nodeSelector: *nodeSelector
  tolerations: *tolerations
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
    limits:
      cpu: 200m
      memory: 200Mi
  admissionWebhooks:
    patch:
      nodeSelector: *nodeSelector
      tolerations: *tolerations

kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeEtcd:
  enabled: false
