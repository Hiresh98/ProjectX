#requires -Version 5.1
# Remove the app (Helm release + namespace). This also frees the ALB.
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

Write-Host "=== [app] removing ===" -ForegroundColor Cyan
helm uninstall projectx -n projectx 2>$null
kubectl delete namespace projectx --ignore-not-found --timeout=120s 2>$null
Write-Host "[app] DOWN (ALB released)." -ForegroundColor Green
