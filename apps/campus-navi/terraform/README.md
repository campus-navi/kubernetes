# 모니터링 인프라 Terraform

이 코드는 이번에 eksctl/aws cli/helm/kubectl로 **수동으로 이미 구축한** 모니터링 스택을
그대로 재현하도록 작성됐습니다. 지금 클러스터에 이미 다 떠 있는 상태이므로, 이 코드를
그대로 `terraform apply`하면 **동일한 이름의 리소스가 이미 존재해서 충돌 에러**가 납니다.
아래 둘 중 하나를 선택하세요.

## 방법 A. 기존 리소스를 Terraform state로 편입 (추천, 실무에서 흔히 씀)

```bash
terraform init

# OIDC provider (eksctl utils associate-iam-oidc-provider로 이미 만들어져 있음)
aws iam list-open-id-connect-providers
terraform import aws_iam_openid_connect_provider.eks <위에서_나온_ARN>

terraform import aws_eks_node_group.monitoring campus-navi-cluster:ng-monitoring
terraform import aws_iam_role.ebs_csi_driver AmazonEKS_EBS_CSI_DriverRole
terraform import aws_iam_role_policy_attachment.ebs_csi_driver \
  AmazonEKS_EBS_CSI_DriverRole/arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
terraform import aws_eks_addon.ebs_csi campus-navi-cluster:aws-ebs-csi-driver
terraform import kubernetes_storage_class.gp3 gp3

# helm_release, kubectl_manifest는 import가 까다로우므로(리소스 식별자 불일치 이슈)
# 이 세 개(kube-prometheus-stack, ServiceMonitor, PrometheusRule)는
# 방법 B처럼 지우고 terraform apply로 새로 만드는 걸 권장
```

**import는 한 번에 다 하지 말고 하나씩 하고 그때마다 `terraform plan`으로 diff 확인할 것.**
diff가 크게 나오면 tfvars 값(subnet, node role arn 등)이 실제와 다른 건지 먼저 의심해볼 것.

## 방법 B. 지우고 Terraform으로 재생성 (학습 목적이면 이게 더 깔끔함)

```bash
# helm/kubectl로 만든 것부터 역순으로 삭제
kubectl delete -f ../06-alerting-rules.yaml
kubectl delete -f ../03-springboot-servicemonitor.yaml
helm uninstall kube-prometheus-stack -n monitoring
aws eks delete-addon --cluster-name campus-navi-cluster --addon-name aws-ebs-csi-driver --region ap-northeast-2
aws eks delete-nodegroup --cluster-name campus-navi-cluster --nodegroup-name ng-monitoring --region ap-northeast-2
# IAM role(AmazonEKS_EBS_CSI_DriverRole)은 eksctl create iamserviceaccount로 만들었으니
# eksctl delete iamserviceaccount로 지우거나 IAM 콘솔에서 직접 삭제

# 그 다음
cp terraform.tfvars.example terraform.tfvars   # 값 채우기
terraform init
terraform plan
terraform apply
```

## 실행 전 체크리스트

- `terraform.tfvars` 채우기 (discord_webhook_url, grafana_admin_password는 절대 git에 커밋 금지)
- `aws_iam_openid_connect_provider.eks`가 이미 클러스터에 있는지 확인 후 중복 생성 방지
  ```bash
  aws eks describe-cluster --name campus-navi-cluster --query 'cluster.identity.oidc.issuer'
  aws iam list-open-id-connect-providers
  ```
- PVC(20Gi+5Gi+5Gi = 30Gi gp3)는 그대로 비용 발생하는 리소스이니 인지하고 진행
