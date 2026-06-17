#requires -Version 5.1
<#
  Tear down stacks. Default = COST-SAVING: removes only the billable stacks
  (app, addons, irsa, eks, nat, bastion) and keeps the free layer (rds, rds-sg,
  ecr, vpc, iam) at ~$0. Use -All to destroy everything.
#>
[CmdletBinding()]
param([switch]$All)
$ErrorActionPreference = "Continue"
$Stacks = $PSScriptRoot

$costly = @("app", "addons", "irsa", "eks", "nat", "bastion")
$free   = @("rds", "rds-sg", "ecr", "vpc")
$order  = if ($All) { $costly + $free } else { $costly }

foreach ($s in $order) {
  $p = Join-Path $Stacks "$s\down.ps1"
  if (Test-Path $p) {
    Write-Host "`n##### DOWN STACK: $s #####" -ForegroundColor Magenta
    & $p
  }
}

if ($All) {
  Write-Host "`nEverything destroyed (iam + github-oidc, if used, must be removed separately)." -ForegroundColor Green
} else {
  Write-Host "`nCostly stacks removed. Free layer (vpc/ecr/rds/iam) still running at ~`$0." -ForegroundColor Green
  Write-Host "Use -All to remove the free layer too." -ForegroundColor Green
}
