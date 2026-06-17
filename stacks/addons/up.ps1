#requires -Version 5.1
# Install cluster add-ons: metrics-server, AWS Load Balancer Controller,
# Cluster Autoscaler, and Argo CD. Requires the eks + irsa stacks to be UP.
$ErrorActionPreference = "Stop"
$Dir = $PSScriptRoot
$env:Path = (@(
  [System.Environment]::GetEnvironmentVariable("Path", "Machine"),
  [System.Environment]::GetEnvironmentVariable("Path", "User"),
  "$env:ProgramFiles\Amazon\AWSCLIV2",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
) | Where-Object { $_ }) -join ';'

function Section($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Tf($stack, $name) { terraform -chdir="$Dir\..\$stack" output -raw $name 2>$null }

$CLUSTER = Tf "eks" "cluster_name"
$REGION  = Tf "eks" "region"
$VPC_ID  = Tf "vpc" "vpc_id"
$LB_ROLE = Tf "irsa" "lb_controller_role_arn"
$CA_ROLE = Tf "irsa" "cluster_autoscaler_role_arn"
if (-not $CLUSTER) { throw "eks stack not deployed (no cluster_name). Run stacks/eks/up.ps1 first." }

Section "Configuring kubectl"
aws eks update-kubeconfig --name $CLUSTER --region $REGION

Section "Helm repos"
helm repo add eks https://aws.github.io/eks-charts | Out-Null
helm repo add autoscaler https://kubernetes.github.io/autoscaler | Out-Null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ | Out-Null
helm repo update | Out-Null

Section "metrics-server"
helm upgrade --install metrics-server metrics-server/metrics-server --namespace kube-system --wait

Section "AWS Load Balancer Controller"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --set "clusterName=$CLUSTER" `
  --set "region=$REGION" `
  --set "vpcId=$VPC_ID" `
  --set "serviceAccount.create=true" `
  --set "serviceAccount.name=aws-load-balancer-controller" `
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$LB_ROLE" `
  --wait

Section "Cluster Autoscaler"
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler `
  --namespace kube-system `
  --set "autoDiscovery.clusterName=$CLUSTER" `
  --set "awsRegion=$REGION" `
  --set "rbac.serviceAccount.create=true" `
  --set "rbac.serviceAccount.name=cluster-autoscaler" `
  --set "rbac.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$CA_ROLE" `
  --wait

Section "Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd `
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=available deployment --all --timeout=300s

Write-Host "`n[addons] UP." -ForegroundColor Green
