param([string]$Godot = 'C:\Users\sebsp\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $repoRoot 'builds\GrimTable-0.15.0-windows-x86_64'
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
$env:APPDATA = Join-Path $repoRoot '.runtime'
$env:LOCALAPPDATA = Join-Path $repoRoot '.runtime\Local'
$exportLog = Join-Path $repoRoot '.runtime\armies-0150\windows-export.log'
$exePath = Join-Path $releaseRoot 'GrimTable.exe'
$process = Start-Process -FilePath $Godot -ArgumentList @('--headless','--path',$repoRoot,'--export-release','"Windows Desktop"',$exePath,'--log-file',$exportLog) -PassThru -WindowStyle Hidden
$process.WaitForExit()
if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exePath)) { throw "Godot export failed. Inspect $exportLog" }
foreach ($name in @('LICENSE','THIRD_PARTY_NOTICES.md')) { Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination $releaseRoot }
$engineLicense = Join-Path $repoRoot 'builds\GrimTable-0.14.0-windows-x86_64\GODOT_LICENSES.txt'
if (Test-Path -LiteralPath $engineLicense) { Copy-Item -LiteralPath $engineLicense -Destination $releaseRoot }
Write-Output "Exported $exePath"
