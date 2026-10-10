param(
    [Parameter(Mandatory=$true)]
    [string]$ZipPath,
    [string]$WorkDir = (Join-Path $env:TEMP ("dyness-rs485-github-" + (Get-Date -Format "yyyyMMddHHmmss")))
)
$ErrorActionPreference = "Stop"
$ZipPath = (Resolve-Path $ZipPath).Path
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required. Install Git for Windows first."
}
if (-not (Test-Path $ZipPath -PathType Leaf)) {
    throw "ZIP file does not exist."
}
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$repo = Join-Path $WorkDir "dyness-rs485-venus"
git clone https://github.com/adrien3287/dyness-rs485-venus.git $repo
if ($LASTEXITCODE -ne 0) { throw "Git clone failed." }
Expand-Archive -Path $ZipPath -DestinationPath $repo -Force
$essential = @(
    "snapshot/data/apps/dbus-serialbattery/bms/dyness_powerhaus.py",
    "snapshot/data/apps/dbus-serialbattery/bms/dyness_powerhaus_protocol.py",
    "snapshot/data/apps/dyness_powerhaus_v0_2/aggregate_dbus.py",
    "snapshot/data/apps/DynessDetails/DynessDetails.json",
    "snapshot/data/apps/available/SerialbatteryGui/gui-v2/SerialbatteryGui.json",
    "scripts/install.sh",
    "MANIFEST.sha256"
)
foreach ($rel in $essential) {
    if (-not (Test-Path (Join-Path $repo $rel))) {
        throw "Missing required file in ZIP: $rel"
    }
}
Push-Location $repo
try {
    git add -A
    if ($LASTEXITCODE -ne 0) { throw "git add failed" }
    git status --short
    Write-Host ""
    Write-Host "Publishing to a PUBLIC GitHub repository. Source files and reference configurations will be publicly visible."
    $choice = Read-Host "Type PUBLIER to continue"
    if ($choice -cne "PUBLIER") { throw "Cancelled; no GitHub changes were sent." }
    git commit -m "Backup: current Dyness PowerHaus RS485 reader, aggregator and GUI v5"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed (check Git identity and status)" }
    git push origin main
    if ($LASTEXITCODE -ne 0) { throw "git push failed: check GitHub credentials" }
    Write-Host "Published: https://github.com/adrien3287/dyness-rs485-venus"
}
finally {
    Pop-Location
}
