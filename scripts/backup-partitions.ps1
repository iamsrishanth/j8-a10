<#
.SYNOPSIS
  Quick boot/system/vendor/recovery dump from a rooted device or a
  shell-capable recovery (not sideload mode).

.DESCRIPTION
  Simpler than backup-device.ps1: it dumps four partitions by fixed block count
  and does not verify hashes. Use backup-device.ps1 when you need verified,
  identity-aware backups. This one is for "get a copy of boot before I flash".

.EXAMPLE
  pwsh ./scripts/backup-partitions.ps1 -Serial R58M12ABC -OutDir D:\j8-backup
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,

    [string]$OutDir = (Join-Path $PWD "backup"),
    [string]$Adb = "adb",
    [switch]$AsRoot
)

$ErrorActionPreference = "Stop"

# Counts are 4 KiB blocks matching the partition sizes in docs/device.md.
$parts = @(
    @{ Name = "boot";     Count = 8192   },  # 33,554,432 B
    @{ Name = "recovery"; Count = 8192   },  # 33,554,432 B
    @{ Name = "system";   Count = 829440 },  # 3,397,386,240 B
    @{ Name = "vendor";   Count = 122880 }   # 503,316,480 B
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "Output: $OutDir"

if ($AsRoot) {
    Write-Host "Requesting root adb..."
    & $Adb -s $Serial root | Out-Null
    Start-Sleep -Seconds 2
    & $Adb -s $Serial wait-for-device
}

$whoami = (& $Adb -s $Serial shell id) -join ""
if ($whoami -notmatch "uid=0") {
    throw "adb is not root (got: $whoami). Use -AsRoot, or run from TWRP, or use backup-device.ps1."
}
Write-Host "adb root confirmed."

foreach ($p in $parts) {
    $name   = $p.Name
    $remote = "/data/local/tmp/$name.img"
    $local  = Join-Path $OutDir "$name.img"

    Write-Host "Dumping $name (system takes a while)..."
    & $Adb -s $Serial shell "dd if=/dev/block/by-name/$name of=$remote bs=4096 count=$($p.Count) 2>/dev/null"
    & $Adb -s $Serial pull $remote $local | Out-Null
    & $Adb -s $Serial shell "rm -f $remote"

    $len = (Get-Item $local).Length
    $hash = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLower()
    Write-Host ("  {0,-9} {1,12:N0} B  {2}" -f $name, $len, $hash)
}

Write-Host ""
Write-Host "Done. Copy these files off the machine before flashing."
