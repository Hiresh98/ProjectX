#!/usr/bin/env bash
# One-click bring-up of the ProjectX EKS stack.
# Prereqs: aws cli (configured), terraform, kubectl, helm, docker.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform/envs/dev"
APP_DIR="$REPO_ROOT/app"
CHART_DIR="$REPO_ROOT/helm/projectx"
SKIP_BUILD="${SKIP_BUILD:-false}"

section() { echo -e "\n=== $1 ==="; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1"; exit 1; }; }

section "Checking prerequisites"
for t in aws terraform kubectl helm docker; do need "$t"; done
aws sts get-caller-identity >/dev/null
echo "AWS credentials OK."

section "Terraform apply (infrastructure)"
terraform -chdir="$TF_DIR" init -input=false
terraform -chdir="$TF_DIR" apply -auto-approve -input=false

tf() { terraform -chdir="$TF_DIR" output -raw "$1"; }
REGION="$(tf region)"
CLUSTER="$(tf cluster_name)"
ECR_URL="$(tf ecr_repository_url)"
VPC_ID="$(tf vpc_id)"
LB_ROLE="$(tf lb_controller_role_arn)"
CA_ROLE="$(tf cluster_autoscaler_role_arn)"
DB_HOST="$(tf db_host)"
DB_PORT="$(tf db_port)"
DB_NAME="$(tf db_name)"
DB_USER="$(tf db_username)"
DB_PASS="$(tf db_password)"
REGISTRY="${ECR_URL%%/*}"

section "Configuring kubectl"
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

section "Installing cluster add-ons"
helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo add autoscaler https://kubernetes.github.io/autoscaler >/dev/null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update >/dev/null

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system --wait

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$LB_ROLE" \
  --wait

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName="$CLUSTER" \
  --set awsRegion="$REGION" \
  --set rbac.serviceAccount.create=true \
  --set rbac.serviceAccount.name=cluster-autoscaler \
  --set "rbac.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$CA_ROLE" \
  --wait

# Argo CD via official manifest + server-side apply (Helm chart hangs on Helm v4).
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=available deployment --all --timeout=300s

section "Creating app namespace + DB secret"
kubectl create namespace projectx --dry-run=client -o yaml | kubectl apply -f -
kubectl -n projectx create secret generic projectx-db \
  --from-literal=DB_PASSWORD="$DB_PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

if [ "$SKIP_BUILD" != "true" ]; then
  section "Building + pushing image to ECR"
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
  docker build -t "$ECR_URL:latest" "$APP_DIR"
  docker push "$ECR_URL:latest"
fi

section "Deploying app via Helm"
helm upgrade --install projectx "$CHART_DIR" \
  --namespace projectx \
  --set image.repository="$ECR_URL" \
  --set image.tag=latest \
  --set database.host="$DB_HOST" \
  --set database.port="$DB_PORT" \
  --set database.name="$DB_NAME" \
  --set database.user="$DB_USER" \
  --set database.existingSecret=projectx-db \
  --wait --timeout 5m

section "Waiting for ALB endpoint"
HOST=""
for i in $(seq 1 40); do
  HOST="$(kubectl -n projectx get ingress projectx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  [ -n "$HOST" ] && break
  sleep 15
  echo "  ...still provisioning ALB ($i/40)"
done

echo -e "\n========================================"
if [ -n "$HOST" ]; then
  echo " ProjectX is UP"
  echo " URL:  http://$HOST"
else
  echo " App deployed; ALB not ready yet -> kubectl -n projectx get ingress projectx"
fi
echo " Argo CD admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "========================================"
