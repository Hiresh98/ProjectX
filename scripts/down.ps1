#requires -Version 5.1
<#
.SYNOPSIS
  One-click teardown of the entire ProjectX stack (deletes everything).

.DESCRIPTION
  Order matters: Kubernetes-created AWS resources (the ALB + its security
  groups / ENIs) must be removed BEFORE 'terraform destroy', otherwise the
  VPC delete hangs. This script:
    1. uninstalls the app (removes the Ingress -> ALB)
    2. force-deletes any leftover LoadBalancer services / ingresses
    3. uninstalls cluster add-ons + Argo CD
    4. terraform destroy (VPC, EKS, ECR, RDS, IAM)
#>
[CmdletBinding()]
param(
  [switch]$Force
)

$ErrorActionPreference = "Continue"   # keep going through best-effort cleanup
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir    = Join-Path $RepoRoot "terraform\envs\dev"

function Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# --- Ensure required CLIs are on PATH (handles terminals opened before install) ---
function Initialize-ToolPath {
  $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
  $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
  $extra = @(
    "$env:ProgramFiles\Amazon\AWSCLIV2",
    "$env:ProgramFiles\Docker\Docker\resources\bin",
    "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
    "$env:ProgramFiles\GitHub CLI"
  )
  $env:Path = (@($machine, $user) + $extra | Where-Object { $_ }) -join ';'
}
Initialize-ToolPath

# Hard requirement: without terraform we cannot destroy. Fail loudly (never pretend).
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  Write-Host "ERROR: 'terraform' not found on PATH. Install it and reopen your terminal." -ForegroundColor Red
  Write-Host "       (winget install -e --id Hashicorp.Terraform)" -ForegroundColor Red
  exit 1
}

if (-not $Force) {
  $ans = Read-Host "This will DELETE ALL ProjectX AWS resources. Type 'yes' to continue"
  if ($ans -ne "yes") { Write-Host "Aborted."; exit 1 }
}

# Best-effort Kubernetes cleanup first so the ALB/ENIs are released before destroy.
Push-Location $TfDir
try { $tf = terraform output -json 2>$null | ConvertFrom-Json } catch { $tf = $null }
Pop-Location

if ($tf -and $tf.cluster_name) {
  aws eks update-kubeconfig --name $tf.cluster_name.value --region $tf.region.value 2>$null | Out-Null

  Section "Removing app + Ingress (frees the ALB)"
  helm uninstall projectx -n projectx 2>$null

  Section "Force-deleting any leftover LB-backed resources"
  kubectl delete ingress --all -A --timeout=120s 2>$null
  kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --timeout=120s 2>$null

  Write-Host "Waiting 60s for ALB/ENI cleanup..."
  Start-Sleep -Seconds 60

  Section "Uninstalling cluster add-ons"
  kubectl delete namespace argocd --ignore-not-found --timeout=120s 2>$null
  helm uninstall cluster-autoscaler -n kube-system 2>$null
  helm uninstall aws-load-balancer-controller -n kube-system 2>$null
  helm uninstall metrics-server -n kube-system 2>$null
}
else {
  Write-Host "Could not read Terraform outputs (cluster may already be gone). Proceeding to destroy." -ForegroundColor Yellow
}

Section "Terraform destroy (infrastructure)"
Push-Location $TfDir
try {
  terraform init -input=false | Out-Null
  terraform destroy -auto-approve -input=false
  $destroyExit = $LASTEXITCODE
}
finally { Pop-Location }

Write-Host ""
if ($destroyExit -eq 0) {
  Write-Host "========================================" -ForegroundColor Green
  Write-Host " ProjectX is DOWN. All resources destroyed." -ForegroundColor Green
  Write-Host " Tip: verify in the AWS console that no ALB/EIP/ENI lingers." -ForegroundColor Green
  Write-Host "========================================" -ForegroundColor Green
}
else {
  Write-Host "========================================" -ForegroundColor Red
  Write-Host " TEARDOWN FAILED (terraform destroy exit code: $destroyExit)." -ForegroundColor Red
  Write-Host " Resources may STILL be running and billing. Re-run ./scripts/down.ps1" -ForegroundColor Red
  Write-Host " after fixing the error above." -ForegroundColor Red
  Write-Host "========================================" -ForegroundColor Red
  exit $destroyExit
}
