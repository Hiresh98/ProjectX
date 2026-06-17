#requires -Version 5.1
<#
  Bring up the whole platform by running each stack's up.ps1 in dependency order.
  Optional stacks (bastion, github-oidc, iam) are NOT included here - run their
  own up.ps1 when needed.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$Stacks = $PSScriptRoot
$order = @("vpc", "ecr", "rds-sg", "rds", "nat", "eks", "irsa", "addons", "app")

foreach ($s in $order) {
  Write-Host "`n##### STACK: $s #####" -ForegroundColor Magenta
  & (Join-Path $Stacks "$s\up.ps1")
  if ($LASTEXITCODE -ne 0) { throw "Stack '$s' failed." }
}
Write-Host "`nAll stacks UP." -ForegroundColor Green
