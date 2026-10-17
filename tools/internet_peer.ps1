param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][ValidateSet('host','guest')][string]$Role,
    [Parameter(Mandatory=$true)][string]$SignalingUrl,
    [string]$RoomCode = '',
    [switch]$ForceTurn,
    [switch]$KeepSignaling,
    [ValidateRange(0,300)][int]$HoldSeconds = 0,
    [ValidateRange(0,1000)][int]$DelayMs = 0,
    [switch]$Source,
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
if (-not $SignalingUrl.StartsWith('wss://')) { throw 'Public test requires WSS.' }
if ($Role -eq 'guest' -and $RoomCode -notmatch '^[A-Za-z2-9]{6}$') { throw 'Enter the host room code.' }
$project = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $project ('.runtime/internet-peer-' + $Role + '-' + (Get-Date -Format yyyyMMdd-HHmmss)) }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$env:APPDATA = Join-Path $OutputDirectory 'appdata'
$env:LOCALAPPDATA = $env:APPDATA
$arguments = @()
if ($Source) { $arguments += @('--path', ('"' + $project + '"')) }
$arguments += @('--', '--public-test', ('--network-smoke-' + $Role), ('--signal-url=' + $SignalingUrl), ('--test-hold-seconds=' + $HoldSeconds))
if ($Role -eq 'guest') { $arguments += ('--room-code=' + $RoomCode.ToUpperInvariant()) }
if ($ForceTurn) { $arguments += '--force-turn' }
if ($KeepSignaling) { $arguments += '--keep-signaling' }
if ($DelayMs -gt 0) { $arguments += ('--net-delay-ms=' + $DelayMs) }
Write-Output 'Run the other role on a genuinely different network. This script cannot verify network separation.'
Write-Output ('Logs: ' + $OutputDirectory + ' (read host.log to obtain the room code)')
$peer = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $OutputDirectory ($Role + '.log')) -RedirectStandardError (Join-Path $OutputDirectory ($Role + '.err'))
$deadline = (Get-Date).AddSeconds(420 + $HoldSeconds)
try {
    while (-not $peer.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    if (-not $peer.HasExited) { throw 'Peer test timed out.' }
    $result = Get-Content -LiteralPath (Join-Path $OutputDirectory ($Role + '.log')) -Encoding UTF8 -Raw
    Write-Output $result
    if ($result -notmatch 'NETWORK SMOKE PASS') { throw 'Peer test failed. Read both peers logs before reporting an internet pass.' }
} finally {
    if (-not $peer.HasExited) { Stop-Process -Id $peer.Id }
}
