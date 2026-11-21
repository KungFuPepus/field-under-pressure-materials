<#
.SYNOPSIS
    Export the entire MongoDB project database to a gzip-compressed archive (.archive.gz) on Windows.

.DESCRIPTION
    Dumps all collections, documents, indexes, and validators from the project database into
    db\backups\field_under_pressure_yyyyMMdd_HHmmss.archive.gz (or a custom path).
    Uses container file copy (docker compose cp) to avoid PowerShell binary piping corruption.

.EXAMPLE
    .\db\scripts\backup.ps1
    .\db\scripts\backup.ps1 .\custom.archive.gz
    $env:MONGO_URI="mongodb://..."; .\db\scripts\backup.ps1
#>
param(
    [Parameter(Position = 0)]
    [string]$OutFile = ""
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

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $ResolvedOutFile = Join-Path $BackupDir "${MongoDb}_${Timestamp}.archive.gz"
} else {
    $ResolvedOutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
}

$OutParent = Split-Path -Parent $ResolvedOutFile
if (-not (Test-Path $OutParent)) {
    New-Item -ItemType Directory -Path $OutParent -Force | Out-Null
}

$TmpLocalFile = "${ResolvedOutFile}.tmp.${PID}"
$TmpContainerFile = "/tmp/fup_backup_${PID}.archive.gz"

try {
    if ($env:MONGO_URI) {
        if (-not (Get-Command "mongodump" -ErrorAction SilentlyContinue)) {
            throw "mongodump is required in PATH when MONGO_URI is set."
        }
        Invoke-Native "mongodump" @(
            "--uri=$($env:MONGO_URI)",
            "--db", $MongoDb,
            "--archive=$TmpLocalFile",
            "--gzip"
        )
    } else {
        Push-Location $RepoRoot
        try {
            try {
                Invoke-Native "docker" @(
                    "compose", "exec", "-T", "mongodb",
                    "mongodump",
                    "--username", $MongoUser,
                    "--password", $MongoPass,
                    "--authenticationDatabase", "admin",
                    "--db", $MongoDb,
                    "--archive=$TmpContainerFile",
                    "--gzip"
                )
                Invoke-Native "docker" @(
                    "compose", "cp", "mongodb:$TmpContainerFile", $TmpLocalFile
                )
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

    Move-Item -Path $TmpLocalFile -Destination $ResolvedOutFile -Force
    $SizeKB = [Math]::Round((Get-Item $ResolvedOutFile).Length / 1KB, 1)
    Write-Host "[backup] Database '${MongoDb}' exported to: ${ResolvedOutFile} (${SizeKB} KB)"
} catch {
    if (Test-Path $TmpLocalFile) {
        Remove-Item -Path $TmpLocalFile -Force -ErrorAction SilentlyContinue
    }
    throw
}
