#!/usr/bin/env bash
# Install cluster add-ons. Requires the eks + irsa stacks to be UP.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tf() { terraform -chdir="$DIR/../$1" output -raw "$2" 2>/dev/null || true; }

CLUSTER="$(tf eks cluster_name)"
REGION="$(tf eks region)"
VPC_ID="$(tf vpc vpc_id)"
LB_ROLE="$(tf irsa lb_controller_role_arn)"
CA_ROLE="$(tf irsa cluster_autoscaler_role_arn)"
[ -n "$CLUSTER" ] || { echo "eks stack not deployed. Run stacks/eks/up.sh first."; exit 1; }

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo add autoscaler https://kubernetes.github.io/autoscaler >/dev/null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null
helm repo update >/dev/null

helm upgrade --install metrics-server metrics-server/metrics-server --namespace kube-system --wait

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set "clusterName=$CLUSTER" --set "region=$REGION" --set "vpcId=$VPC_ID" \
  --set "serviceAccount.create=true" --set "serviceAccount.name=aws-load-balancer-controller" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$LB_ROLE" --wait

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set "autoDiscovery.clusterName=$CLUSTER" --set "awsRegion=$REGION" \
  --set "rbac.serviceAccount.create=true" --set "rbac.serviceAccount.name=cluster-autoscaler" \
  --set "rbac.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$CA_ROLE" --wait

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=available deployment --all --timeout=300s

echo "[addons] UP."
