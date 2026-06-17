#requires -Version 5.1
# Build + push the app image to ECR and deploy it via Helm.
# Requires the ecr, eks and rds stacks to be UP (and the addons stack for the ALB).
$ErrorActionPreference = "Stop"
$Dir      = $PSScriptRoot
$RepoRoot = (Get-Item $Dir).Parent.Parent.FullName
$AppDir   = Join-Path $RepoRoot "app"
$ChartDir = Join-Path $RepoRoot "helm\projectx"

$env:Path = (@(
  [System.Environment]::GetEnvironmentVariable("Path", "Machine"),
  [System.Environment]::GetEnvironmentVariable("Path", "User"),
  "$env:ProgramFiles\Amazon\AWSCLIV2",
  "$env:ProgramFiles\Docker\Docker\resources\bin",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
) | Where-Object { $_ }) -join ';'

function Section($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Tf($stack, $name) { terraform -chdir="$Dir\..\$stack" output -raw $name 2>$null }

$ECR_URL  = Tf "ecr" "repository_url"
$REGISTRY = Tf "ecr" "registry"
$CLUSTER  = Tf "eks" "cluster_name"
$REGION   = Tf "eks" "region"
$DB_HOST  = Tf "rds" "db_host"
$DB_PORT  = Tf "rds" "db_port"
$DB_NAME  = Tf "rds" "db_name"
$DB_USER  = Tf "rds" "db_username"
$DB_PASS  = Tf "rds" "db_password"
if (-not $ECR_URL) { throw "ecr stack not deployed. Run stacks/ecr/up.ps1 first." }
if (-not $CLUSTER) { throw "eks stack not deployed. Run stacks/eks/up.ps1 first." }

Section "Configuring kubectl"
aws eks update-kubeconfig --name $CLUSTER --region $REGION

Section "Building + pushing image to ECR"
$IMAGE = "$ECR_URL`:latest"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY
docker build -t $IMAGE $AppDir
docker push $IMAGE

Section "Namespace + DB secret"
kubectl create namespace projectx --dry-run=client -o yaml | kubectl apply -f -
kubectl -n projectx create secret generic projectx-db `
  --from-literal=DB_PASSWORD=$DB_PASS --dry-run=client -o yaml | kubectl apply -f -

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
  Write-Host " [app] UP -> http://$hostname" -ForegroundColor Green
} else {
  Write-Host " [app] deployed; ALB hostname not ready yet." -ForegroundColor Yellow
  Write-Host " Check: kubectl -n projectx get ingress projectx"
}
Write-Host "========================================" -ForegroundColor Green
