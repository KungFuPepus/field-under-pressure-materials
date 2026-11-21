<#
.SYNOPSIS
    Initialize and start the MongoDB Docker container on Windows (PowerShell 5.1+ / 7+).

.DESCRIPTION
    Builds the MongoDB Docker image and starts the container via Docker Compose.
    On first start (or with -Reset), the latest archive in db\backups\ is restored automatically.

.EXAMPLE
    .\db\scripts\init.ps1
    .\db\scripts\init.ps1 -Reset
#>
param(
    [switch]$Reset
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

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$MongoUser = if ($env:MONGO_ROOT_USER) { $env:MONGO_ROOT_USER } else { "admin" }
$MongoPass = if ($env:MONGO_ROOT_PASSWORD) { $env:MONGO_ROOT_PASSWORD } else { "admin123" }
$MongoDb   = if ($env:MONGO_DB) { $env:MONGO_DB } else { "field_under_pressure" }
$MongoPort = if ($env:MONGO_PORT) { $env:MONGO_PORT } else { "27017" }

# Verify Docker daemon is reachable
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& docker info *> $null
$dockerCode = $LASTEXITCODE
$ErrorActionPreference = $prevPref
if ($dockerCode -ne 0) {
    Write-Error "Docker is not running. Start Docker Desktop and try again."
    exit 1
}

Push-Location $RepoRoot
try {
    if ($Reset) {
        Write-Host "[init] Stopping container and removing volume..."
        Invoke-Native "docker" @("compose", "down", "-v")
    }

    Write-Host "[init] Building image and starting MongoDB container..."
    Invoke-Native "docker" @("compose", "up", "-d", "--build")

    Write-Host "[init] Waiting for MongoDB to accept authenticated connections..."
    $ready = $false
    for ($i = 0; $i -lt 45; $i++) {
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & docker compose exec -T mongodb mongosh --quiet `
            --username $MongoUser `
            --password $MongoPass `
            --authenticationDatabase admin `
            $MongoDb `
            --eval "db.adminCommand('ping').ok" *> $null
        $pingCode = $LASTEXITCODE
        $ErrorActionPreference = $prevPref
        if ($pingCode -eq 0) {
            $ready = $true
            break
        }
        Start-Sleep -Seconds 1
    }

    if (-not $ready) {
        throw "Timed out waiting for MongoDB container to become ready. Check logs with: docker compose logs mongodb"
    }

    Write-Host "[init] MongoDB is ready. Collections in '${MongoDb}':"
    Invoke-Native "docker" @(
        "compose", "exec", "-T", "mongodb",
        "mongosh", "--quiet",
        "--username", $MongoUser,
        "--password", $MongoPass,
        "--authenticationDatabase", "admin",
        $MongoDb,
        "--eval", "db.getCollectionNames().sort().forEach(c => print(' - ' + c + ': ' + db.getCollection(c).countDocuments({}) + ' docs'))"
    )

    Write-Host ""
    Write-Host "[init] Connection string:"
    Write-Host "mongodb://${MongoUser}:${MongoPass}@localhost:${MongoPort}/${MongoDb}?authSource=admin"
} finally {
    Pop-Location
}
