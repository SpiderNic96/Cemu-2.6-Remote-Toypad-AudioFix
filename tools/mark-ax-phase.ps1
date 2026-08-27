[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Phase,
    [string]$OutputDirectory = "$(Join-Path (Get-Location) 'ax-session')"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$markerFile = Join-Path $OutputDirectory 'markers.ndjson'

$record = [ordered]@{
    captured_at = (Get-Date -Format o)
    phase = $Phase
    note = if ($args.Count -gt 0) { $args -join ' ' } else { $null }
}
($record | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $markerFile
Write-Host "Marked phase: $Phase"
