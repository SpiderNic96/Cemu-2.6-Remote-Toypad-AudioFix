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
        throw "Could not find log.txt. Start Cemu once, enable SoundAPI logging, then rerun with -CemuLogPath <path>."
    }

    return (Get-Item $candidates[0]).FullName
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$logPath = Find-CemuLog -ExplicitPath $CemuLogPath
$eventFile = Join-Path $OutputDirectory 'ax-events.ndjson'
$rawFile = Join-Path $OutputDirectory 'cemu-log-snapshot.txt'
$metaFile = Join-Path $OutputDirectory 'session.txt'

@(
    "Started: $(Get-Date -Format o)",
    "Log: $logPath",
    "Host: $env:COMPUTERNAME",
    "User: $env:USERNAME",
    "Purpose: LEGO Dimensions AX runtime investigation",
    "Collector: incremental, read-only log watcher"
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

function Test-Relevant([string]$line) {
    foreach ($pattern in $patterns) {
        if ($line -like "*$pattern*") { return $true }
    }
    return $false
}

function Write-Event([string]$line) {
    $record = [ordered]@{
        captured_at = (Get-Date -Format o)
        line = $line
    }
    ($record | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $eventFile
    Write-Host $line
}

Write-Host "Watching: $logPath"
Write-Host "Output:  $OutputDirectory"
Write-Host "Use mark-ax-phase.ps1 in another PowerShell window to label moments."
Write-Host "Press Ctrl+C to stop."

$lastLineCount = 0
while ($true) {
    Start-Sleep -Milliseconds 500
    if (-not (Test-Path -LiteralPath $logPath)) { continue }

    $all = Get-Content -LiteralPath $logPath
    $lineCount = @($all).Count

    # Cemu may recreate/truncate its log. If that happens, start from the beginning
    # of the new file rather than duplicating the old tail.
    if ($lineCount -lt $lastLineCount) {
        $lastLineCount = 0
    }

    if ($lineCount -gt $lastLineCount) {
        $newLines = $all[$lastLineCount..($lineCount - 1)]
        foreach ($line in $newLines) {
            if (Test-Relevant $line) {
                Write-Event $line
            }
        }
        $all | Select-Object -Last 5000 | Set-Content -Encoding UTF8 $rawFile
        $lastLineCount = $lineCount
    }
}
