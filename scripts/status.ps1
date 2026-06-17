#requires -Version 5.1
<#
.SYNOPSIS
  Health/status dashboard for the whole ProjectX stack.

.DESCRIPTION
  Read-only. Checks AWS identity, Terraform outputs, EKS nodes, core add-ons,
  Argo CD, the app (deployment/HPA/Ingress/pods), RDS, and does a live HTTP
  probe of the public ALB URL. Prints a PASS/WARN/FAIL line for each.

.EXAMPLE
  ./scripts/status.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "SilentlyContinue"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir    = Join-Path $RepoRoot "terraform\envs\dev"

# Ensure required CLIs are on PATH even if this terminal predates their install.
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = (@($machinePath, $userPath,
  "$env:ProgramFiles\Amazon\AWSCLIV2",
  "$env:ProgramFiles\Docker\Docker\resources\bin",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links") | Where-Object { $_ }) -join ';'

$script:pass = 0; $script:warn = 0; $script:fail = 0

function Line($label, $state, $detail) {
  switch ($state) {
    "OK"   { $c = "Green";  $tag = "[ OK ]"; $script:pass++ }
    "WARN" { $c = "Yellow"; $tag = "[WARN]"; $script:warn++ }
    "FAIL" { $c = "Red";    $tag = "[FAIL]"; $script:fail++ }
    default { $c = "Gray";  $tag = "[ -- ]" }
  }
  Write-Host ("{0}  {1,-26} {2}" -f $tag, $label, $detail) -ForegroundColor $c
}
function Head($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

# ---------- Identity & Terraform outputs ----------
Head "AWS & Terraform"
$who = aws sts get-caller-identity --query Arn --output text 2>$null
if ($who) { Line "AWS credentials" "OK" $who } else { Line "AWS credentials" "FAIL" "not authenticated"; }

$REGION  = terraform -chdir="$TfDir" output -raw region 2>$null
$CLUSTER = terraform -chdir="$TfDir" output -raw cluster_name 2>$null
$ECR_URL = terraform -chdir="$TfDir" output -raw ecr_repository_url 2>$null
$DB_HOST = terraform -chdir="$TfDir" output -raw db_host 2>$null
if (-not $REGION) { $REGION = "ap-south-1" }

$baseUp    = [bool]$ECR_URL    # free layer (VPC/ECR/RDS) present
$computeUp = [bool]$CLUSTER    # costly layer (EKS/NAT/nodes) present

if ($computeUp)  { Line "Terraform state" "OK" "compute UP  cluster=$CLUSTER region=$REGION" }
elseif ($baseUp) { Line "Terraform state" "WARN" "free layer UP, compute DOWN (cost-saving)" }
else             { Line "Terraform state" "--" "nothing deployed" }

# Always report the free/free-tier layer when it exists.
if ($baseUp) {
  Head "Free layer (kept, ~`$0)"
  $ecrName = aws ecr describe-repositories --region $REGION --query "repositories[?contains(repositoryUri, 'projectx')].repositoryName | [0]" --output text 2>$null
  if ($ecrName -and $ecrName -ne "None") { Line "ECR (images)" "OK" $ecrName } else { Line "ECR (images)" "WARN" "not found" }
  $rdsBase = aws rds describe-db-instances --region $REGION --query "DBInstances[?contains(Endpoint.Address, 'projectx')].DBInstanceStatus | [0]" --output text 2>$null
  if ($rdsBase -eq "available") { Line "RDS (data)" "OK" "available ($DB_HOST)" }
  elseif ($rdsBase -and $rdsBase -ne "None") { Line "RDS (data)" "WARN" $rdsBase } else { Line "RDS (data)" "WARN" "not found" }
}

if (-not $computeUp) {
  if ($baseUp) {
    Write-Host "`nCompute layer is DOWN (cost-saving). Free layer (VPC/ECR/RDS) still running at ~`$0." -ForegroundColor Yellow
    Write-Host "Run ./scripts/up.ps1 to restore compute (data + images preserved)." -ForegroundColor Yellow
  } else {
    Write-Host "`nNothing is deployed. Run ./scripts/up.ps1 first." -ForegroundColor Yellow
  }
  Write-Host "`n========================================" -ForegroundColor Cyan
  Write-Host (" PASS: {0}   WARN: {1}   FAIL: {2}" -f $script:pass, $script:warn, $script:fail) -ForegroundColor $(if ($script:fail -gt 0) {"Red"} elseif ($script:warn -gt 0) {"Yellow"} else {"Green"})
  Write-Host "========================================" -ForegroundColor Cyan
  return
}

aws eks update-kubeconfig --name $CLUSTER --region $REGION 2>$null | Out-Null

# ---------- EKS cluster ----------
Head "EKS Cluster"
$cstatus = aws eks describe-cluster --name $CLUSTER --region $REGION --query "cluster.status" --output text 2>$null
if ($cstatus -eq "ACTIVE") { Line "Control plane" "OK" $cstatus } else { Line "Control plane" "FAIL" "$cstatus" }

$nodesReady = (kubectl get nodes --no-headers 2>$null | Select-String " Ready ").Count
$nodesTotal = (kubectl get nodes --no-headers 2>$null | Measure-Object).Count
if ($nodesTotal -gt 0 -and $nodesReady -eq $nodesTotal) { Line "Worker nodes" "OK" "$nodesReady/$nodesTotal Ready" }
elseif ($nodesReady -gt 0) { Line "Worker nodes" "WARN" "$nodesReady/$nodesTotal Ready" }
else { Line "Worker nodes" "FAIL" "0 Ready" }

# ---------- Core add-ons ----------
Head "Cluster Add-ons (kube-system)"
function CheckDeploy($ns, $selector, $label) {
  $ready = kubectl -n $ns get deploy -l $selector -o jsonpath='{.items[*].status.readyReplicas}' 2>$null
  $want  = kubectl -n $ns get deploy -l $selector -o jsonpath='{.items[*].status.replicas}' 2>$null
  if (-not $want) { Line $label "FAIL" "not installed"; return }
  $r = ($ready -split ' ' | Measure-Object -Sum).Sum
  $w = ($want  -split ' ' | Measure-Object -Sum).Sum
  if ($r -ge $w -and $w -gt 0) { Line $label "OK" "$r/$w ready" } else { Line $label "WARN" "$r/$w ready" }
}
CheckDeploy "kube-system" "app.kubernetes.io/name=aws-load-balancer-controller" "AWS LB Controller"
CheckDeploy "kube-system" "app.kubernetes.io/name=aws-cluster-autoscaler"      "Cluster Autoscaler"
CheckDeploy "kube-system" "app.kubernetes.io/name=metrics-server"              "Metrics Server"
CheckDeploy "kube-system" "k8s-app=kube-dns"                                   "CoreDNS"

# ---------- Argo CD ----------
Head "Argo CD"
$argoTotal = (kubectl -n argocd get pods --no-headers 2>$null | Measure-Object).Count
$argoRun   = (kubectl -n argocd get pods --no-headers 2>$null | Select-String " Running ").Count
if ($argoTotal -gt 0 -and $argoRun -eq $argoTotal) { Line "Argo CD pods" "OK" "$argoRun/$argoTotal Running" }
elseif ($argoTotal -gt 0) { Line "Argo CD pods" "WARN" "$argoRun/$argoTotal Running" }
else { Line "Argo CD pods" "FAIL" "not installed" }

# ---------- App ----------
Head "Application (projectx)"
$depReady = kubectl -n projectx get deploy projectx -o jsonpath='{.status.readyReplicas}' 2>$null
$depWant  = kubectl -n projectx get deploy projectx -o jsonpath='{.spec.replicas}' 2>$null
if ($depReady -and $depReady -eq $depWant) { Line "Deployment" "OK" "$depReady/$depWant ready" }
elseif ($depReady) { Line "Deployment" "WARN" "$depReady/$depWant ready" }
else { Line "Deployment" "FAIL" "not deployed" }

$hpa = kubectl -n projectx get hpa projectx -o jsonpath='{.status.currentReplicas}/{.spec.maxReplicas} cpu={.status.currentCPUUtilizationPercentage}%' 2>$null
if ($hpa) { Line "HPA (min/max 1/3)" "OK" $hpa } else { Line "HPA" "WARN" "not found" }

$pods = kubectl -n projectx get pods -l app.kubernetes.io/name=projectx --no-headers 2>$null
$podsRun = ($pods | Select-String " Running ").Count
$podsTot = ($pods | Measure-Object).Count
Line "App pods" $(if ($podsRun -eq $podsTot -and $podsTot -gt 0) {"OK"} else {"WARN"}) "$podsRun/$podsTot Running"

$alb = kubectl -n projectx get ingress projectx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
if ($alb) { Line "ALB / Ingress" "OK" $alb } else { Line "ALB / Ingress" "FAIL" "no hostname yet" }

# ---------- RDS ----------
Head "Database (RDS)"
$rds = aws rds describe-db-instances --region $REGION --query "DBInstances[?contains(Endpoint.Address, 'projectx')].DBInstanceStatus | [0]" --output text 2>$null
if ($rds -eq "available") { Line "PostgreSQL" "OK" "$rds ($DB_HOST)" }
elseif ($rds) { Line "PostgreSQL" "WARN" $rds }
else { Line "PostgreSQL" "FAIL" "not found" }

# ---------- Live HTTP probe ----------
Head "Live endpoint probe"
if ($alb) {
  $url = "http://$alb"
  try {
    $r = Invoke-WebRequest -Uri "$url/healthz" -UseBasicParsing -TimeoutSec 10
    Line "HTTP /healthz" $(if ($r.StatusCode -eq 200) {"OK"} else {"WARN"}) "HTTP $($r.StatusCode)  ->  $url"
  } catch { Line "HTTP /healthz" "WARN" "no response yet (ALB may still be warming): $url" }
} else { Line "HTTP probe" "WARN" "skipped (no ALB hostname)" }

# ---------- Summary ----------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host (" PASS: {0}   WARN: {1}   FAIL: {2}" -f $script:pass, $script:warn, $script:fail) -ForegroundColor $(if ($script:fail -gt 0) {"Red"} elseif ($script:warn -gt 0) {"Yellow"} else {"Green"})
if ($alb) { Write-Host (" App URL: http://{0}" -f $alb) -ForegroundColor Green }
Write-Host "========================================" -ForegroundColor Cyan
