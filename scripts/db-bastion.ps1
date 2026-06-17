#requires -Version 5.1
<#
.SYNOPSIS
  Create (or remove) a small free-tier SSH bastion so you can reach the PRIVATE
  RDS database from local tools like DBeaver via an SSH tunnel.

.DESCRIPTION
  RDS is private (no public IP; SG allows 5432 only from inside the VPC). This
  spins up a t3.micro bastion in a public subnet, locks SSH down to your current
  public IP, auto-generates an SSH key (bastion-key.pem), and prints the exact
  DBeaver connection + SSH-tunnel settings. The compute layer (EKS/NAT) is left
  in whatever state it's already in, so this also works on the $0 free layer.

.EXAMPLE
  .\db-bastion.ps1                 # create bastion, allow only my IP
.EXAMPLE
  .\db-bastion.ps1 -AllowedCidr 0.0.0.0/0   # allow from anywhere (less secure)
.EXAMPLE
  .\db-bastion.ps1 -Down           # remove the bastion (keeps RDS + free layer)
#>
[CmdletBinding()]
param(
  [switch]$Down,
  [string]$AllowedCidr
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$TfDir    = Join-Path $RepoRoot "terraform\envs\dev"

# Ensure CLIs are on PATH even if this terminal predates their install.
$env:Path = (@([System.Environment]::GetEnvironmentVariable("Path", "Machine"),
  [System.Environment]::GetEnvironmentVariable("Path", "User"),
  "$env:ProgramFiles\Amazon\AWSCLIV2") | Where-Object { $_ }) -join ';'

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  Write-Host "ERROR: 'terraform' not found on PATH. Install it and reopen your terminal." -ForegroundColor Red
  exit 1
}

function Section($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }

Push-Location $TfDir
try {
  terraform init -input=false | Out-Null

  # Preserve whatever the compute layer is currently set to.
  $compute = terraform output -raw compute_enabled 2>$null
  if ($compute -ne "true") { $compute = "false" }

  if ($Down) {
    Section "Removing bastion (keeping RDS + free layer)"
    terraform apply -auto-approve -input=false `
      -var="enable_compute=$compute" -var="enable_bastion=false"
    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed (exit $LASTEXITCODE)" }
    Write-Host "`nBastion removed. RDS and the free layer are untouched." -ForegroundColor Green
    return
  }

  # Default: lock SSH to the caller's current public IP.
  if (-not $AllowedCidr) {
    try {
      $ip = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com" -TimeoutSec 10).Trim()
      $AllowedCidr = "$ip/32"
    } catch {
      $AllowedCidr = "0.0.0.0/0"
      Write-Host "Could not detect your public IP; allowing 0.0.0.0/0 (less secure)." -ForegroundColor Yellow
    }
  }

  Section "Creating bastion (SSH allowed from $AllowedCidr)"
  terraform apply -auto-approve -input=false `
    -var="enable_compute=$compute" -var="enable_bastion=true" `
    -var="bastion_allowed_cidr=$AllowedCidr"
  if ($LASTEXITCODE -ne 0) { throw "terraform apply failed (exit $LASTEXITCODE)" }

  $bastionIp = terraform output -raw bastion_public_ip 2>$null
  $keyPath   = terraform output -raw bastion_key_path 2>$null
  $dbHost    = terraform output -raw db_host 2>$null
  $dbName    = terraform output -raw db_name 2>$null
  $dbUser    = terraform output -raw db_username 2>$null
  $dbPass    = terraform output -raw db_password 2>$null
}
finally { Pop-Location }

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Bastion ready. DBeaver -> New PostgreSQL connection:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host " MAIN tab:" -ForegroundColor Cyan
Write-Host "   Host     : $dbHost"
Write-Host "   Port     : 5432"
Write-Host "   Database : $dbName"
Write-Host "   Username : $dbUser"
Write-Host "   Password : $dbPass"
Write-Host ""
Write-Host " SSH tab (enable 'Use SSH Tunnel'):" -ForegroundColor Cyan
Write-Host "   Host/IP        : $bastionIp"
Write-Host "   Port           : 22"
Write-Host "   User Name      : ec2-user"
Write-Host "   Auth Method    : Public Key"
Write-Host "   Private Key    : $TfDir\bastion-key.pem"
Write-Host ""
Write-Host " Then click 'Test Connection'. When done, remove it with:" -ForegroundColor Yellow
Write-Host "   .\scripts\db-bastion.ps1 -Down" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
