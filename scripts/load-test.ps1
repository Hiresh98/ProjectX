#requires -Version 5.1
<#
.SYNOPSIS
  Simple parallel load generator to trigger the HPA (pods scale 1 -> 3).

.EXAMPLE
  ./scripts/load-test.ps1 -Url http://<alb-dns> -Concurrency 50 -Seconds 180
#>
param(
  [Parameter(Mandatory = $true)][string]$Url,
  [int]$Concurrency = 50,
  [int]$Seconds = 180,
  [int]$BusyMs = 200
)

$target = "$($Url.TrimEnd('/'))/load?ms=$BusyMs"
Write-Host "Hammering $target with $Concurrency workers for $Seconds s..." -ForegroundColor Cyan
Write-Host "Watch scaling in another terminal:  kubectl -n projectx get hpa,pods -w" -ForegroundColor Yellow

$jobs = 1..$Concurrency | ForEach-Object {
  Start-Job -ScriptBlock {
    param($u, $secs)
    $end = (Get-Date).AddSeconds($secs)
    while ((Get-Date) -lt $end) {
      try { Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 30 | Out-Null } catch {}
    }
  } -ArgumentList $target, $Seconds
}

$jobs | Wait-Job | Out-Null
$jobs | Remove-Job
Write-Host "Done. Check final state: kubectl -n projectx get hpa,pods" -ForegroundColor Green
