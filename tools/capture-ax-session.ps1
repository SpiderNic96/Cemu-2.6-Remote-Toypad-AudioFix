[CmdletBinding()]
param(
    [string]$CemuLogPath,
    [string]$OutputDirectory = "$(Join-Path (Get-Location) 'ax-session')"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-CemuLog {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "Cemu log not found: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $candidates = @(
        (Join-Path (Get-Location) 'log.txt'),
        (Join-Path (Get-Location) 'bin\log.txt'),
        (Join-Path $env:APPDATA 'Cemu\log.txt'),
        (Join-Path $env:LOCALAPPDATA 'Cemu\log.txt')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if (-not $candidates) {
        throw "Could not find log.txt. Start Cemu once, enable SoundAPI logging, then rerun this script with -CemuLogPath <path>."
    }

    return (Get-Item $candidates[0]).FullName
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$logPath = Find-CemuLog -ExplicitPath $CemuLogPath
$eventFile = Join-Path $OutputDirectory 'ax-events.ndjson'
$rawFile = Join-Path $OutputDirectory 'cemu-log-snapshot.txt'
$metaFile = Join-Path $OutputDirectory 'session.txt'
$markerFile = Join-Path $OutputDirectory 'markers.ndjson'

@(
    "Started: $(Get-Date -Format o)",
    "Log: $logPath",
    "Host: $env:COMPUTERNAME",
    "User: $env:USERNAME",
    "Purpose: LEGO Dimensions AX runtime investigation",
    "This collector does not modify Cemu or audio output."
) | Set-Content -Encoding UTF8 $metaFile

$patterns = @(
    'LEGO-AUDIO-DIAG',
    'AXSetVoiceVe',
    'AXSetVoiceDeviceMix',
    'AXSetVoiceRmtMix',
    'AXSetVoiceRmtOn',
    'AXSetVoiceSrc',
    'AXSetVoiceSrcRatio',
    'AXSetVoiceDevice'
)

function Write-Event([string]$line) {
    $record = [ordered]@{
        captured_at = (Get-Date -Format o)
        line = $line
    }
    ($record | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $eventFile
    Write-Host $line
}

function Get-FileLength([string]$path) {
    try { return (Get-Item -LiteralPath $path).Length } catch { return 0 }
}

Write-Host "Watching: $logPath"
Write-Host "Output:  $OutputDirectory"
Write-Host "Press Ctrl+C to stop."

$initialLength = Get-FileLength $logPath
Get-Content -LiteralPath $logPath -Tail 0 | Out-Null

$lastLength = $initialLength
while ($true) {
    Start-Sleep -Milliseconds 750
    if (-not (Test-Path -LiteralPath $logPath)) { continue }

    $length = Get-FileLength $logPath
    if ($length -lt $lastLength) {
        $lastLength = 0
    }

    if ($length -gt $lastLength) {
        $all = Get-Content -LiteralPath $logPath
        $startIndex = [Math]::Max(0, $all.Count - 2500)
        for ($i = $startIndex; $i -lt $all.Count; $i++) {
            $line = $all[$i]
            if ($patterns | Where-Object { $line -like "*$_*" }) {
                Write-Event $line
            }
        }
        $lastLength = $length
        $all | Select-Object -Last 5000 | Set-Content -Encoding UTF8 $rawFile
    }
}
