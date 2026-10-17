param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$Project = (Split-Path -Parent $PSScriptRoot),
    [string]$SignalingUrl = 'ws://127.0.0.1:8080',
    [switch]$Lan,
    [switch]$FactionContent,
    [switch]$RelayOnly,
    [switch]$KeepSignaling,
    [int]$HoldSeconds = 0,
    [ValidateRange(0,1000)][int]$DelayMs = 0,
    [switch]$Exported
)
$ErrorActionPreference = 'Stop'
$runDirectory = Join-Path $Project ('.runtime/network-smoke-' + (Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$common = if ($Exported) { @() } else { @('--headless', '--path', ('"' + $Project + '"')) }
$common += @('--', ('--signal-url=' + $SignalingUrl))
if ($Lan) { $common += '--lan' }
if ($FactionContent) { $common += '--content-smoke' }
if ($RelayOnly) { $common += '--force-turn' }
if ($KeepSignaling) { $common += '--keep-signaling' }
if ($HoldSeconds -gt 0) { $common += ('--test-hold-seconds=' + $HoldSeconds) }
if ($DelayMs -gt 0) { $common += ('--net-delay-ms=' + $DelayMs) }
function Start-Peer([string]$Role, [string]$Code = '') {
    $env:APPDATA = Join-Path $runDirectory $Role
    $env:LOCALAPPDATA = $env:APPDATA
    $arguments = $common + ('--network-smoke-' + $Role)
    if ($Code) { $arguments += ('--room-code=' + $Code) }
    Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runDirectory ($Role + '.log')) -RedirectStandardError (Join-Path $runDirectory ($Role + '.err'))
}
$hostPeer = Start-Peer 'host'
try {
    $code = ''
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline -and -not $hostPeer.HasExited) {
        $content = Get-Content -LiteralPath (Join-Path $runDirectory 'host.log') -Raw -ErrorAction SilentlyContinue
        if ($Lan -or $content -match 'SMOKE ROOM ([A-Z2-9]{6})') { if (-not $Lan) { $code = $Matches[1] }; break }
        Start-Sleep -Milliseconds 200
    }
    if (-not $Lan -and -not $code) { throw 'Host did not create a room. See logs.' }
    $guestPeer = Start-Peer 'guest' $code
    $deadline = (Get-Date).AddSeconds(100 + $HoldSeconds)
    while ((-not $hostPeer.HasExited -or -not $guestPeer.HasExited) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    if (-not $hostPeer.HasExited -or -not $guestPeer.HasExited) { throw 'Peer test timed out.' }
    $hostLog = Get-Content -LiteralPath (Join-Path $runDirectory 'host.log') -Raw
    $guestLog = Get-Content -LiteralPath (Join-Path $runDirectory 'guest.log') -Raw
    if ($hostLog -notmatch 'NETWORK SMOKE PASS' -or $guestLog -notmatch 'NETWORK SMOKE PASS') { throw 'Peer test failed. See logs.' }
    $hostHash = [regex]::Match($hostLog, 'SMOKE HASH (\w+)').Groups[1].Value
    $guestHash = [regex]::Match($guestLog, 'SMOKE HASH (\w+)').Groups[1].Value
    if (-not $hostHash -or $hostHash -ne $guestHash) { throw 'Final state hashes differ.' }
    $hostCombat = [regex]::Match($hostLog, 'SMOKE COMBAT (.+)').Groups[1].Value.Trim()
    $guestCombat = [regex]::Match($guestLog, 'SMOKE COMBAT (.+)').Groups[1].Value.Trim()
    if (-not $hostCombat -or $hostCombat -ne $guestCombat) { throw 'Recorded combat differs.' }
    $hostDice = @(([regex]::Match($hostLog, 'SMOKE DICE (.+)').Groups[1].Value | ConvertFrom-Json))
    $guestDice = @(([regex]::Match($guestLog, 'SMOKE DICE (.+)').Groups[1].Value | ConvertFrom-Json))
    if ($hostDice.Count -eq 0 -or $hostDice.Count -ne $guestDice.Count) { throw 'Dice history counts differ.' }
    for ($index = 0; $index -lt $hostDice.Count; $index++) {
        $hostFaces = @($hostDice[$index].values | ForEach-Object { [int]$_ }) -join ','
        $guestFaces = @($guestDice[$index].values | ForEach-Object { [int]$_ }) -join ','
        if ($hostFaces -ne $guestFaces -or [int]$hostDice[$index].total -ne [int]$guestDice[$index].total) { throw 'Recorded dice differ.' }
    }
    $hostObjectives = [regex]::Match($hostLog, 'SMOKE OBJECTIVES (.+)').Groups[1].Value.Trim()
    $guestObjectives = [regex]::Match($guestLog, 'SMOKE OBJECTIVES (.+)').Groups[1].Value.Trim()
    if (-not $hostObjectives -or $hostObjectives -ne $guestObjectives) { throw 'Objective control differs.' }
    Write-Output ('GRIMTABLE TWO-INSTANCE PASS · state ' + $hostHash + ' · ' + $runDirectory)
} finally {
    foreach ($peerProcess in @($hostPeer, $guestPeer)) {
        if ($peerProcess -and -not $peerProcess.HasExited) { Stop-Process -Id $peerProcess.Id }
    }
    Write-Output ('Logs: ' + $runDirectory)
}
