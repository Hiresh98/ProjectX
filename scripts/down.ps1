#requires -Version 5.1
<#
.SYNOPSIS
  Teardown for ProjectX. Two modes:

    .\down.ps1              -> COST-SAVING teardown (default).
                               Deletes only the resources that BILL:
                               EKS control plane, EC2 worker nodes, NAT Gateway,
                               Elastic IP, ALB, IRSA roles.
                               KEEPS the free / free-tier layer running at ~$0:
                               VPC, subnets, IGW, security groups, ECR (images),
                               RDS db.t3.micro (your data), IAM.

    .\down.ps1 -DestroyAll  -> FULL teardown. Destroys absolutely everything,
                               including the VPC, ECR images and the RDS database.

.DESCRIPTION
  Order matters: Kubernetes-created AWS resources (the ALB + its security groups
  / ENIs) must be removed BEFORE Terraform changes the VPC, otherwise deletes
  hang. This script uninstalls the app/add-ons first, then runs Terraform.
#>
[CmdletBinding()]
param(
  [switch]$Force,
  [switch]$DestroyAll
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

if ($DestroyAll) {
  $prompt = "FULL teardown: this DELETES EVERYTHING incl. the VPC, ECR images and RDS DATABASE. Type 'yes'"
} else {
  $prompt = "Cost-saving teardown: deletes EKS/nodes/NAT/ALB, KEEPS VPC/ECR/RDS (free). Type 'yes'"
}
if (-not $Force) {
  $ans = Read-Host $prompt
  if ($ans -ne "yes") { Write-Host "Aborted."; exit 1 }
}

# Best-effort Kubernetes cleanup first so the ALB/ENIs are released before TF runs.
Push-Location $TfDir
try { $tf = terraform output -json 2>$null | ConvertFrom-Json } catch { $tf = $null }
Pop-Location

if ($tf -and $tf.cluster_name -and $tf.cluster_name.value) {
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
  Write-Host "No live cluster found (already down or never up). Continuing." -ForegroundColor Yellow
}

Push-Location $TfDir
try {
  terraform init -input=false | Out-Null
  if ($DestroyAll) {
    Section "Terraform destroy (EVERYTHING)"
    terraform destroy -auto-approve -input=false
  }
  else {
    Section "Terraform apply -var enable_compute=false (remove costly layer, keep free layer)"
    terraform apply -auto-approve -input=false -var="enable_compute=false"
  }
  $tfExit = $LASTEXITCODE
}
finally { Pop-Location }

Write-Host ""
if ($tfExit -eq 0) {
  if ($DestroyAll) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " ProjectX is FULLY DOWN. Everything destroyed." -ForegroundColor Green
    Write-Host " Tip: verify no ALB/EIP/ENI lingers in the console." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
  }
  else {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " Costly layer removed. Free layer still running (~`$0):" -ForegroundColor Green
    Write-Host "   KEPT : VPC, subnets, IGW, SGs, ECR (images), RDS (data), IAM" -ForegroundColor Green
    Write-Host "   GONE : EKS, EC2 nodes, NAT Gateway, EIP, ALB, IRSA roles" -ForegroundColor Green
    Write-Host " Run .\scripts\up.ps1 to bring compute back (data/images preserved)." -ForegroundColor Green
    Write-Host " Run .\scripts\down.ps1 -DestroyAll to remove the free layer too." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
  }
}
else {
  Write-Host "========================================" -ForegroundColor Red
  Write-Host " TEARDOWN FAILED (terraform exit code: $tfExit)." -ForegroundColor Red
  Write-Host " Resources may STILL be running and billing. Re-run after fixing the error above." -ForegroundColor Red
  Write-Host "========================================" -ForegroundColor Red
  exit $tfExit
}
