#requires -Version 5.1
# Uninstall cluster add-ons (Argo CD, Cluster Autoscaler, LB Controller, metrics-server).
$ErrorActionPreference = "Continue"
$Dir = $PSScriptRoot
$env:Path = (@(
  [System.Environment]::GetEnvironmentVariable("Path", "Machine"),
  [System.Environment]::GetEnvironmentVariable("Path", "User"),
  "$env:ProgramFiles\Amazon\AWSCLIV2",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
) | Where-Object { $_ }) -join ';'

$CLUSTER = terraform -chdir="$Dir\..\eks" output -raw cluster_name 2>$null
$REGION  = terraform -chdir="$Dir\..\eks" output -raw region 2>$null
if ($CLUSTER) { aws eks update-kubeconfig --name $CLUSTER --region $REGION 2>$null | Out-Null }

Write-Host "=== [addons] uninstalling ===" -ForegroundColor Cyan
kubectl delete namespace argocd --ignore-not-found --timeout=120s 2>$null
helm uninstall cluster-autoscaler -n kube-system 2>$null
helm uninstall aws-load-balancer-controller -n kube-system 2>$null
helm uninstall metrics-server -n kube-system 2>$null
Write-Host "[addons] DOWN." -ForegroundColor Green
