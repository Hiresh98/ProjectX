#!/usr/bin/env bash
# Teardown for ProjectX.
#   ./down.sh                 -> cost-saving teardown (default): removes the costly
#                                layer (EKS/nodes/NAT/ALB/IRSA), KEEPS the free
#                                layer (VPC/ECR/RDS/IAM) running at ~$0.
#   DESTROY_ALL=true ./down.sh -> full teardown: destroys EVERYTHING incl. VPC/ECR/RDS.
#   FORCE=true ./down.sh       -> skip the confirmation prompt.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform/envs/dev"
FORCE="${FORCE:-false}"
DESTROY_ALL="${DESTROY_ALL:-false}"

section() { echo -e "\n=== $1 ==="; }

if [ "$DESTROY_ALL" = "true" ]; then
  PROMPT="FULL teardown: DELETES EVERYTHING incl. VPC, ECR images and RDS DATABASE. Type 'yes': "
else
  PROMPT="Cost-saving teardown: deletes EKS/nodes/NAT/ALB, KEEPS VPC/ECR/RDS (free). Type 'yes': "
fi
if [ "$FORCE" != "true" ]; then
  read -r -p "$PROMPT" ans
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

terraform -chdir="$TF_DIR" init -input=false >/dev/null
if [ "$DESTROY_ALL" = "true" ]; then
  section "Terraform destroy (EVERYTHING)"
  terraform -chdir="$TF_DIR" destroy -auto-approve -input=false
else
  section "Terraform apply -var enable_compute=false (remove costly layer, keep free layer)"
  terraform -chdir="$TF_DIR" apply -auto-approve -input=false -var="enable_compute=false"
fi
TF_EXIT=$?

echo ""
if [ "$TF_EXIT" -ne 0 ]; then
  echo "========================================"
  echo " TEARDOWN FAILED (terraform exit code: $TF_EXIT). Resources may still bill."
  echo "========================================"
  exit "$TF_EXIT"
fi
if [ "$DESTROY_ALL" = "true" ]; then
  echo "========================================"
  echo " ProjectX is FULLY DOWN. Everything destroyed."
  echo " Verify no ALB/EIP/ENI lingers in the AWS console."
  echo "========================================"
else
  echo "========================================"
  echo " Costly layer removed. Free layer still running (~\$0):"
  echo "   KEPT : VPC, subnets, IGW, SGs, ECR (images), RDS (data), IAM"
  echo "   GONE : EKS, EC2 nodes, NAT Gateway, EIP, ALB, IRSA roles"
  echo " Run ./scripts/up.sh to bring compute back (data/images preserved)."
  echo " Run DESTROY_ALL=true ./scripts/down.sh to remove the free layer too."
  echo "========================================"
fi
