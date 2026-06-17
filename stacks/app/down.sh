#!/usr/bin/env bash
# Remove the app (Helm release + namespace). Frees the ALB.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER="$(terraform -chdir="$DIR/../eks" output -raw cluster_name 2>/dev/null || true)"
REGION="$(terraform -chdir="$DIR/../eks" output -raw region 2>/dev/null || true)"
[ -n "$CLUSTER" ] && aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1 || true

helm uninstall projectx -n projectx 2>/dev/null || true
kubectl delete namespace projectx --ignore-not-found --timeout=120s 2>/dev/null || true
echo "[app] DOWN (ALB released)."
