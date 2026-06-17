#requires -Version 5.1
<#
.SYNOPSIS
  One-click bring-up of the entire ProjectX stack on AWS EKS.

.DESCRIPTION
  1. terraform apply  -> VPC, EKS, node group, ECR, RDS, IRSA roles
  2. configure kubectl
  3. install cluster add-ons (metrics-server, AWS LB controller, cluster-autoscaler, Argo CD)
  4. build + push the app image to ECR
  5. deploy the app via Helm (HPA min 1 / max 3) behind an internet-facing ALB
  6. print the public URL

.NOTES
  Prereqs: aws cli (configured), terraform, kubectl, helm, docker (running).
#>
[CmdletBinding()]
param(
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir    = Join-Path $RepoRoot "terraform\envs\dev"
$AppDir   = Join-Path $RepoRoot "app"
$ChartDir = Join-Path $RepoRoot "helm\projectx"

function Section($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Need($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required tool '$cmd' not found on PATH."
  }
}

# Ensure required CLIs are on PATH even if this terminal was opened before they
# were installed (refresh from registry + add common install dirs).
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

Section "Checking prerequisites"
"aws","terraform","kubectl","helm","docker" | ForEach-Object { Need $_ }
aws sts get-caller-identity | Out-Null
Write-Host "AWS credentials OK." -ForegroundColor Green

Section "Terraform apply (infrastructure)"
Push-Location $TfDir
try {
  terraform init -input=false
  # enable_compute=true provisions the costly layer (EKS/NAT/nodes/IRSA). If a
  # prior cost-saving down.ps1 left the free layer (VPC/ECR/RDS) in place, this
  # reuses it and only rebuilds compute.
  terraform apply -auto-approve -input=false -var="enable_compute=true"
  $tf = terraform output -json | ConvertFrom-Json
}
finally { Pop-Location }

$REGION   = $tf.region.value
$CLUSTER  = $tf.cluster_name.value
$ECR_URL  = $tf.ecr_repository_url.value
$VPC_ID   = $tf.vpc_id.value
$LB_ROLE  = $tf.lb_controller_role_arn.value
$CA_ROLE  = $tf.cluster_autoscaler_role_arn.value
$DB_HOST  = $tf.db_host.value
$DB_PORT  = $tf.db_port.value
$DB_NAME  = $tf.db_name.value
$DB_USER  = $tf.db_username.value
$DB_PASS  = $tf.db_password.value
$REGISTRY = $ECR_URL.Split("/")[0]

Section "Configuring kubectl"
aws eks update-kubeconfig --name $CLUSTER --region $REGION

Section "Installing cluster add-ons"
helm repo add eks https://aws.github.io/eks-charts | Out-Null
helm repo add autoscaler https://kubernetes.github.io/autoscaler | Out-Null
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ | Out-Null
helm repo add argo https://argoproj.github.io/argo-helm | Out-Null
helm repo update | Out-Null

# Metrics Server (required for HPA)
helm upgrade --install metrics-server metrics-server/metrics-server `
  --namespace kube-system --wait

# AWS Load Balancer Controller (provisions the ALB for the Ingress)
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --set "clusterName=$CLUSTER" `
  --set "region=$REGION" `
  --set "vpcId=$VPC_ID" `
  --set "serviceAccount.create=true" `
  --set "serviceAccount.name=aws-load-balancer-controller" `
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$LB_ROLE" `
  --wait

# Cluster Autoscaler (scales nodes 1 -> 3)
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler `
  --namespace kube-system `
  --set "autoDiscovery.clusterName=$CLUSTER" `
  --set "awsRegion=$REGION" `
  --set "rbac.serviceAccount.create=true" `
  --set "rbac.serviceAccount.name=cluster-autoscaler" `
  --set "rbac.serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$CA_ROLE" `
  --wait

# Argo CD (GitOps control plane).
# Installed via the official manifest with server-side apply: the argo-cd Helm
# chart currently hangs under Helm v4, and server-side apply avoids the
# large-CRD annotation size limit that breaks a normal `kubectl apply`.
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd `
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=available deployment --all --timeout=300s

Section "Creating app namespace + DB secret"
kubectl create namespace projectx --dry-run=client -o yaml | kubectl apply -f -
kubectl -n projectx create secret generic projectx-db `
  --from-literal=DB_PASSWORD=$DB_PASS `
  --dry-run=client -o yaml | kubectl apply -f -

if (-not $SkipBuild) {
  Section "Building + pushing image to ECR"
  $IMAGE = "$ECR_URL`:latest"
  aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY
  docker build -t $IMAGE $AppDir
  docker push $IMAGE
}

Section "Deploying app via Helm"
helm upgrade --install projectx $ChartDir `
  --namespace projectx `
  --set "image.repository=$ECR_URL" `
  --set "image.tag=latest" `
  --set "database.host=$DB_HOST" `
  --set "database.port=$DB_PORT" `
  --set "database.name=$DB_NAME" `
  --set "database.user=$DB_USER" `
  --set "database.existingSecret=projectx-db" `
  --wait --timeout 5m

Section "Waiting for ALB endpoint"
$hostname = $null
for ($i = 0; $i -lt 40; $i++) {
  $hostname = kubectl -n projectx get ingress projectx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
  if ($hostname) { break }
  Start-Sleep -Seconds 15
  Write-Host "  ...still provisioning ALB ($($i+1)/40)"
}

Write-Host "`n========================================" -ForegroundColor Green
if ($hostname) {
  Write-Host " ProjectX is UP" -ForegroundColor Green
  Write-Host " URL:  http://$hostname" -ForegroundColor Green
  Write-Host " (ALB DNS can take 1-2 min to resolve)"
} else {
  Write-Host " App deployed, but ALB hostname not ready yet." -ForegroundColor Yellow
  Write-Host " Check: kubectl -n projectx get ingress projectx"
}
Write-Host " Argo CD password:" -ForegroundColor Green
Write-Host '   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | %{[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_))}'
Write-Host "========================================" -ForegroundColor Green
