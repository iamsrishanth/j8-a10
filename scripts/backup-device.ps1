<#
.SYNOPSIS
  Verified partition backup of a Samsung Galaxy J8 (SM-J810G / j8y18lte) over ADB.

.DESCRIPTION
  Dumps the partitions you cannot rebuild from source (identity, calibration,
  radio, boot, recovery) and verifies length + SHA-256 against the device for
  every file.

  userdata is deliberately NOT dumped (privacy, size). system/vendor are not
  dumped by default either — pass -IncludeSystem to add them.

  This is NOT a full rollback set. It cannot restore a previous ROM on its own.

.EXAMPLE
  pwsh ./scripts/backup-device.ps1 -Serial R58M12ABC -BackupRoot D:\j8-backup

.EXAMPLE
  pwsh ./scripts/backup-device.ps1 -Serial R58M12ABC -IncludeSystem -BackupRoot D:\j8-backup
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,

    [string]$Adb = "adb",
    [string]$BackupRoot = (Join-Path $PWD "j8-backup"),
    [switch]$IncludeSystem
)

$ErrorActionPreference = "Stop"

$Stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
$OutDir     = Join-Path $BackupRoot "$Serial\$Stamp"
$RemoteDir  = "/data/local/tmp/j8-backup-$Stamp"
$ManifestPath = Join-Path $OutDir "backup.json"
$TranscriptPath = Join-Path $OutDir "backup.log"

if (Test-Path -LiteralPath $OutDir) {
    throw "Backup destination already exists: $OutDir"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Start-Transcript -Path $TranscriptPath | Out-Null

function Invoke-AdbShell {
    param([string]$Command)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $Adb -s $Serial shell $Command 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) {
        throw "adb shell failed ($code): $Command`n$($output -join "`n")"
    }
    return (($output | Out-String).Trim())
}

function Get-Prop([string]$Name) {
    return ((& $Adb -s $Serial shell getprop $Name 2>&1 | Out-String).Trim())
}

function Invoke-AdbPull {
    param([string]$Remote, [string]$Local)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $Adb -s $Serial pull $Remote $Local 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) {
        throw "adb pull failed ($code): $Remote -> $Local`n$($output -join "`n")"
    }
}

try {
    $state = ((& $Adb -s $Serial get-state 2>&1 | Out-String).Trim())
    if ($LASTEXITCODE -ne 0 -or $state -ne "device") {
        throw "ADB transport not ready for '$Serial' (state=$state). In recovery, check authorisation."
    }

    $id = Invoke-AdbShell "id"
    $isRoot = $id -match "uid=0"

    Write-Host "Device : $Serial"
    Write-Host "Model  : $(Get-Prop ro.product.model) / $(Get-Prop ro.product.device)"
    Write-Host "Build  : $(Get-Prop ro.build.display.id)"
    Write-Host "Root   : $isRoot"
    if (-not $isRoot) {
        Write-Warning "adbd is not root. In TWRP it usually is; in Android you may need 'adb root' or 'su -c'."
        Write-Warning "Partition reads will fail without root — the script will stop at the first one."
    }

    # Partitions worth keeping. 'Sensitive' = identity/calibration, restore with care.
    $parts = @(
        @{ Name = "boot";     Group = "boot";     Sensitive = $false },
        @{ Name = "recovery"; Group = "boot";     Sensitive = $false },
        @{ Name = "misc";     Group = "boot";     Sensitive = $false },
        @{ Name = "efs";      Group = "identity"; Sensitive = $true  },
        @{ Name = "persist";  Group = "identity"; Sensitive = $true  },
        @{ Name = "modemst1"; Group = "identity"; Sensitive = $true  },
        @{ Name = "modemst2"; Group = "identity"; Sensitive = $true  },
        @{ Name = "fsg";      Group = "identity"; Sensitive = $true  },
        @{ Name = "fsc";      Group = "identity"; Sensitive = $true  },
        @{ Name = "config";   Group = "identity"; Sensitive = $true  }
    )
    if ($IncludeSystem) {
        $parts += @{ Name = "system"; Group = "system"; Sensitive = $false }
        $parts += @{ Name = "vendor"; Group = "system"; Sensitive = $false }
    }

    $inventory  = @()
    $totalBytes = [int64]0
    foreach ($p in $parts) {
        $block = "/dev/block/by-name/$($p.Name)"
        $check = Invoke-AdbShell "test -b $block && echo BLOCK_OK || echo BLOCK_MISSING"
        if ($check -notmatch "BLOCK_OK") {
            Write-Warning "skipping $($p.Name): $block does not exist"
            continue
        }
        $bytes = [int64](Invoke-AdbShell "blockdev --getsize64 $block")
        if ($bytes -le 0) { throw "invalid size for $($p.Name): $bytes" }
        $totalBytes += $bytes
        $inventory  += [ordered]@{
            name      = $p.Name
            group     = $p.Group
            block     = $block
            bytes     = $bytes
            sensitive = $p.Sensitive
        }
    }

    # Space checks: device staging + local disk.
    $dfLine   = Invoke-AdbShell "df -k /data/local/tmp | tail -n 1"
    $dfFields = @($dfLine -split "\s+")
    if ($dfFields.Count -ge 4 -and $dfFields[3] -match "^\d+$") {
        $availableKb = [int64]$dfFields[3]
        $requiredKb  = [int64](($totalBytes + 512MB) / 1KB)
        if ($availableKb -lt $requiredKb) {
            throw "not enough device staging space: need ${requiredKb} KiB, have ${availableKb} KiB"
        }
    }

    Invoke-AdbShell "mkdir -p $RemoteDir" | Out-Null
    $records = @()

    foreach ($part in $parts) {
        $name   = $part.Name
        $block  = "/dev/block/by-name/$name"
        $remote = "$RemoteDir/$name.img"
        $localDir = Join-Path $OutDir $part.Group
        New-Item -ItemType Directory -Force -Path $localDir | Out-Null
        $local = Join-Path $localDir "$name.img"

        Write-Host "Dumping $name ($($part.Group)) ..."
        $bytes = [int64](Invoke-AdbShell "blockdev --getsize64 $block")
        Invoke-AdbShell "dd if=$block of=$remote bs=1M 2>/dev/null; sync" | Out-Null

        $remoteBytes = [int64](Invoke-AdbShell "stat -c %s $remote")
        if ($remoteBytes -ne $bytes) {
            throw "dump length mismatch for ${name}: expected $bytes, got $remoteBytes"
        }
        $remoteHash = (Invoke-AdbShell "sha256sum $remote").Split(" ")[0].ToLower()

        Invoke-AdbPull $remote $local

        $localItem = Get-Item -LiteralPath $local
        if ($localItem.Length -ne $bytes) {
            throw "local length mismatch for ${name}: expected $bytes, got $($localItem.Length)"
        }
        $localHash = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLower()
        if ($localHash -ne $remoteHash) {
            throw "SHA-256 mismatch for ${name}: device=$remoteHash local=$localHash"
        }
        Write-Host "  verified: $bytes bytes, $localHash"

        $records += [ordered]@{
            name       = $name
            group      = $part.Group
            block      = $block
            bytes      = $bytes
            sha256     = $localHash
            local_path = $local
            sensitive  = $part.Sensitive
        }
    }

    $manifest = [ordered]@{
        schema_version = 1
        created_utc    = (Get-Date).ToUniversalTime().ToString("o")
        device         = [ordered]@{
            model        = Get-Prop ro.product.model
            device       = Get-Prop ro.product.device
            build        = Get-Prop ro.build.display.id
            bootloader   = Get-Prop ro.boot.bootloader
            verifiedboot = Get-Prop ro.boot.verifiedbootstate
            warranty_bit = Get-Prop ro.boot.warranty_bit
        }
        adb            = $Adb
        backup_root    = $OutDir
        partitions     = $records
        total_bytes    = $totalBytes
        userdata_raw   = "not dumped by design"
        consistency    = "Read from a live system. system/vendor are read-only mounts; efs/persist/cache may be live and are not quiesced."
        device_temp_dir = $RemoteDir
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
    Invoke-AdbShell "rm -rf $RemoteDir" | Out-Null

    Write-Host ""
    Write-Host "BACKUP_OK"
    Write-Host "Manifest : $ManifestPath"
    Write-Host ("Total    : {0:N0} bytes" -f $totalBytes)
    Write-Host ""
    Write-Host "Copy this directory off the machine before flashing anything."
}
catch {
    Write-Host "BACKUP_FAILED: $($_.Exception.Message)"
    throw
}
finally {
    Stop-Transcript | Out-Null
}
