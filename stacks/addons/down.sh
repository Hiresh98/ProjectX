#!/usr/bin/env bash
# Uninstall cluster add-ons.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER="$(terraform -chdir="$DIR/../eks" output -raw cluster_name 2>/dev/null || true)"
REGION="$(terraform -chdir="$DIR/../eks" output -raw region 2>/dev/null || true)"
[ -n "$CLUSTER" ] && aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1 || true

kubectl delete namespace argocd --ignore-not-found --timeout=120s 2>/dev/null || true
helm uninstall cluster-autoscaler -n kube-system 2>/dev/null || true
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
helm uninstall metrics-server -n kube-system 2>/dev/null || true
echo "[addons] DOWN."
