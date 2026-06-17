#requires -Version 5.1
# Create/update this stack. Safe to re-run (idempotent).
$ErrorActionPreference = "Stop"
$Dir = $PSScriptRoot
$env:Path = (@(
  [System.Environment]::GetEnvironmentVariable("Path", "Machine"),
  [System.Environment]::GetEnvironmentVariable("Path", "User"),
  "$env:ProgramFiles\Amazon\AWSCLIV2",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
) | Where-Object { $_ }) -join ';'

$stack = Split-Path $Dir -Leaf
Write-Host "=== [$stack] terraform apply ===" -ForegroundColor Cyan
Push-Location $Dir
try {
  terraform init -input=false
  terraform apply -auto-approve -input=false
  if ($LASTEXITCODE -ne 0) { throw "[$stack] terraform apply failed ($LASTEXITCODE)" }
  Write-Host "[$stack] UP." -ForegroundColor Green
}
finally { Pop-Location }
