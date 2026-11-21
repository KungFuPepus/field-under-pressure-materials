<#
.SYNOPSIS
    Restore the entire MongoDB project database from a shared archive (.archive.gz or .archive) on Windows.

.DESCRIPTION
    Without arguments, automatically restores the newest db\backups\field_under_pressure_*.archive.gz.
    By default replaces the local database cleanly (1:1 mirror). Pass -NoDrop to restore without dropping first.
    Uses container file copy (docker compose cp) to avoid PowerShell binary piping corruption.

.EXAMPLE
    .\db\scripts\restore.ps1
    .\db\scripts\restore.ps1 .\db\backups\field_under_pressure_20261120_235405.archive.gz
    .\db\scripts\restore.ps1 -NoDrop
    $env:MONGO_URI="mongodb://..."; .\db\scripts\restore.ps1
#>
param(
    [Parameter(Position = 0)]
    [string]$ArchiveFile = "",

    [switch]$NoDrop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @Arguments
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($code -ne 0) {
        throw "Command failed with exit code ${code}: $FilePath $($Arguments -join ' ')"
    }
}

$RepoRoot  = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$BackupDir = Join-Path (Join-Path $RepoRoot "db") "backups"

$MongoUser = if ($env:MONGO_ROOT_USER) { $env:MONGO_ROOT_USER } else { "admin" }
$MongoPass = if ($env:MONGO_ROOT_PASSWORD) { $env:MONGO_ROOT_PASSWORD } else { "admin123" }
$MongoDb   = if ($env:MONGO_DB) { $env:MONGO_DB } else { "field_under_pressure" }

if ([string]::IsNullOrWhiteSpace($ArchiveFile)) {
    $Candidates = @(
        Get-ChildItem -Path $BackupDir -Filter "${MongoDb}_*.archive.gz" -File -ErrorAction SilentlyContinue |
            Sort-Object -Property Name
    )
    $FallbackFile = Join-Path $BackupDir "${MongoDb}.archive.gz"

    if ($Candidates.Count -gt 0) {
        $ResolvedArchive = $Candidates[$Candidates.Count - 1].FullName
    } elseif (Test-Path $FallbackFile) {
        $ResolvedArchive = (Resolve-Path $FallbackFile).Path
    } else {
        throw "No archive found in '${BackupDir}' matching '${MongoDb}_*.archive.gz'. Create one first with: .\db\scripts\backup.ps1"
    }
} else {
    $ResolvedArchive = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ArchiveFile)
    if (-not (Test-Path $ResolvedArchive -PathType Leaf)) {
        throw "Archive file not found: ${ResolvedArchive}"
    }
}

Write-Host "[restore] Using archive: ${ResolvedArchive}"

$IsGzip = $ResolvedArchive.EndsWith(".gz", [System.StringComparison]::OrdinalIgnoreCase)
$DropExisting = -not $NoDrop

if ($env:MONGO_URI) {
    if (-not (Get-Command "mongorestore" -ErrorAction SilentlyContinue)) {
        throw "mongorestore is required in PATH when MONGO_URI is set."
    }
    if ($DropExisting -and (Get-Command "mongosh" -ErrorAction SilentlyContinue)) {
        Invoke-Native "mongosh" @(
            "--quiet", $env:MONGO_URI,
            "--eval", "db.getSiblingDB('${MongoDb}').dropDatabase()"
        )
    }

    $RestoreArgs = @("--uri=$($env:MONGO_URI)", "--archive=$ResolvedArchive", "--nsInclude", "${MongoDb}.*")
    if ($IsGzip) { $RestoreArgs += "--gzip" }
    if ($DropExisting) { $RestoreArgs += "--drop" }

    Invoke-Native "mongorestore" $RestoreArgs
} else {
    $Ext = if ($IsGzip) { ".archive.gz" } else { ".archive" }
    $TmpContainerFile = "/tmp/fup_restore_${PID}${Ext}"

    Push-Location $RepoRoot
    try {
        if ($DropExisting) {
            Invoke-Native "docker" @(
                "compose", "exec", "-T", "mongodb",
                "mongosh", "--quiet",
                "--username", $MongoUser,
                "--password", $MongoPass,
                "--authenticationDatabase", "admin",
                $MongoDb,
                "--eval", "db.dropDatabase()"
            )
        }

        try {
            Invoke-Native "docker" @(
                "compose", "cp", $ResolvedArchive, "mongodb:$TmpContainerFile"
            )

            $RestoreArgs = @(
                "compose", "exec", "-T", "mongodb",
                "mongorestore",
                "--username", $MongoUser,
                "--password", $MongoPass,
                "--authenticationDatabase", "admin",
                "--archive=$TmpContainerFile",
                "--nsInclude", "${MongoDb}.*"
            )
            if ($IsGzip) { $RestoreArgs += "--gzip" }
            if ($DropExisting) { $RestoreArgs += "--drop" }

            Invoke-Native "docker" $RestoreArgs
        } finally {
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & docker compose exec -T mongodb rm -f $TmpContainerFile *> $null
            $ErrorActionPreference = $prevPref
        }
    } finally {
        Pop-Location
    }
}

Write-Host "[restore] Database '${MongoDb}' restored from: ${ResolvedArchive}"
