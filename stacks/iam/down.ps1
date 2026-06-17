#requires -Version 5.1
# Destroy this stack so it stops incurring cost. Safe to re-run.
$ErrorActionPreference = "Stop"
$Dir = $PSScriptRoot
$env:Path = (@(
  [System.Environment]::GetEnvironmentVariable("Path", "Machine"),
  [System.Environment]::GetEnvironmentVariable("Path", "User"),
  "$env:ProgramFiles\Amazon\AWSCLIV2",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
) | Where-Object { $_ }) -join ';'

$stack = Split-Path $Dir -Leaf
Write-Host "=== [$stack] terraform destroy ===" -ForegroundColor Cyan
Push-Location $Dir
try {
  terraform init -input=false
  terraform destroy -auto-approve -input=false
  if ($LASTEXITCODE -ne 0) { throw "[$stack] terraform destroy failed ($LASTEXITCODE)" }
  Write-Host "[$stack] DOWN." -ForegroundColor Green
}
finally { Pop-Location }
