#!/usr/bin/env bash
# One-click teardown of the ProjectX EKS stack (deletes everything).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform/envs/dev"
FORCE="${FORCE:-false}"

section() { echo -e "\n=== $1 ==="; }

if [ "$FORCE" != "true" ]; then
  read -r -p "This will DELETE ALL ProjectX AWS resources. Type 'yes' to continue: " ans
  [ "$ans" = "yes" ] || { echo "Aborted."; exit 1; }
fi

CLUSTER="$(terraform -chdir="$TF_DIR" output -raw cluster_name 2>/dev/null || true)"
REGION="$(terraform -chdir="$TF_DIR" output -raw region 2>/dev/null || echo ap-south-1)"

if [ -n "$CLUSTER" ]; then
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1 || true

  section "Removing app + Ingress (frees the ALB)"
  helm uninstall projectx -n projectx 2>/dev/null || true

  section "Force-deleting leftover LB-backed resources"
  kubectl delete ingress --all -A --timeout=120s 2>/dev/null || true
  kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --timeout=120s 2>/dev/null || true

  echo "Waiting 60s for ALB/ENI cleanup..."
  sleep 60

  section "Uninstalling cluster add-ons"
  kubectl delete namespace argocd --ignore-not-found --timeout=120s 2>/dev/null || true
  helm uninstall cluster-autoscaler -n kube-system 2>/dev/null || true
  helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
  helm uninstall metrics-server -n kube-system 2>/dev/null || true
else
  echo "No cluster found in state; proceeding to destroy."
fi

section "Terraform destroy (infrastructure)"
terraform -chdir="$TF_DIR" init -input=false >/dev/null
terraform -chdir="$TF_DIR" destroy -auto-approve -input=false

echo -e "\n========================================"
echo " ProjectX is DOWN. All resources destroyed."
echo " Verify no ALB/EIP/ENI lingers in the AWS console."
echo "========================================"
