#!/usr/bin/env bash
# Build + push the app image to ECR and deploy via Helm.
# Requires the ecr, eks and rds stacks UP (and addons for the ALB).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
APP_DIR="$REPO_ROOT/app"
CHART_DIR="$REPO_ROOT/helm/projectx"
tf() { terraform -chdir="$DIR/../$1" output -raw "$2" 2>/dev/null || true; }

ECR_URL="$(tf ecr repository_url)"
REGISTRY="$(tf ecr registry)"
CLUSTER="$(tf eks cluster_name)"
REGION="$(tf eks region)"
DB_HOST="$(tf rds db_host)"
DB_PORT="$(tf rds db_port)"
DB_NAME="$(tf rds db_name)"
DB_USER="$(tf rds db_username)"
DB_PASS="$(tf rds db_password)"
[ -n "$ECR_URL" ] || { echo "ecr stack not deployed. Run stacks/ecr/up.sh first."; exit 1; }
[ -n "$CLUSTER" ] || { echo "eks stack not deployed. Run stacks/eks/up.sh first."; exit 1; }

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

IMAGE="$ECR_URL:latest"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker build -t "$IMAGE" "$APP_DIR"
docker push "$IMAGE"

kubectl create namespace projectx --dry-run=client -o yaml | kubectl apply -f -
kubectl -n projectx create secret generic projectx-db \
  --from-literal=DB_PASSWORD="$DB_PASS" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install projectx "$CHART_DIR" \
  --namespace projectx \
  --set "image.repository=$ECR_URL" --set "image.tag=latest" \
  --set "database.host=$DB_HOST" --set "database.port=$DB_PORT" \
  --set "database.name=$DB_NAME" --set "database.user=$DB_USER" \
  --set "database.existingSecret=projectx-db" --wait --timeout 5m

echo "[app] UP. Get URL: kubectl -n projectx get ingress projectx"
