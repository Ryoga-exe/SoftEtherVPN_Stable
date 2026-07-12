<#
.SYNOPSIS
Builds the ARM64 OpenSSL and zlib static libraries used by the solution.

.EXAMPLE
.\BuildArm64Dependencies.ps1 `
    -OpenSslSource C:\src\openssl-3.0.9 `
    -ZlibSource C:\src\zlib-1.2.11
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OpenSslSource,

    [Parameter(Mandatory = $true)]
    [string]$ZlibSource,

    [string]$WorkDirectory = (Join-Path $env:TEMP "SoftEtherVPN-arm64-deps"),

    [switch]$KeepWorkDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $Command $($Arguments -join ' ')"
    }
}

if ($env:VSCMD_ARG_TGT_ARCH -ne "arm64") {
    throw "Run this script from an ARM64 Native Tools command prompt."
}

foreach ($command in @("cl.exe", "lib.exe", "nmake.exe", "perl.exe")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command was not found in PATH: $command"
    }
}

$OpenSslSource = (Resolve-Path -LiteralPath $OpenSslSource).Path
$ZlibSource = (Resolve-Path -LiteralPath $ZlibSource).Path

$openSslVersion = Get-Content -LiteralPath (Join-Path $OpenSslSource "VERSION.dat") -Raw
if ($openSslVersion -notmatch '(?m)^MAJOR=3$' -or
    $openSslVersion -notmatch '(?m)^MINOR=0$' -or
    $openSslVersion -notmatch '(?m)^PATCH=9$') {
    throw "OpenSSL 3.0.9 source is required."
}

$zlibHeader = Get-Content -LiteralPath (Join-Path $ZlibSource "zlib.h") -Raw
if ($zlibHeader -notmatch '#define\s+ZLIB_VERSION\s+"1\.2\.11"') {
    throw "zlib 1.2.11 source is required."
}

$outputDirectory = Join-Path $PSScriptRoot "Library\ARM64_Release"
$buildRoot = Join-Path $WorkDirectory ("build-" + [guid]::NewGuid().ToString("N"))
$openSslBuild = Join-Path $buildRoot "openssl-release"
$zlibBuild = Join-Path $buildRoot "zlib-release"

New-Item -ItemType Directory -Path $openSslBuild, $zlibBuild, $outputDirectory -Force | Out-Null

try {
    Push-Location $openSslBuild
    try {
        Invoke-NativeCommand perl.exe (Join-Path $OpenSslSource "Configure") `
            VC-WIN64-ARM no-shared no-tests --release
        Invoke-NativeCommand nmake.exe /NOLOGO build_libs
    }
    finally {
        Pop-Location
    }

    Copy-Item -LiteralPath (Join-Path $openSslBuild "libcrypto.lib") `
        -Destination (Join-Path $outputDirectory "libeay32.lib") -Force
    Copy-Item -LiteralPath (Join-Path $openSslBuild "libssl.lib") `
        -Destination (Join-Path $outputDirectory "ssleay32.lib") -Force

    Copy-Item -Path (Join-Path $ZlibSource "*") -Destination $zlibBuild -Recurse -Force
    Push-Location $zlibBuild
    try {
        Invoke-NativeCommand nmake.exe /NOLOGO /f win32\Makefile.msc LOC=-MT zlib.lib
    }
    finally {
        Pop-Location
    }

    Copy-Item -LiteralPath (Join-Path $zlibBuild "zlib.lib") `
        -Destination (Join-Path $outputDirectory "zlib.lib") -Force

    Write-Host "ARM64 libraries were written to $outputDirectory"
}
finally {
    if (-not $KeepWorkDirectory -and (Test-Path -LiteralPath $buildRoot)) {
        Remove-Item -LiteralPath $buildRoot -Recurse -Force
    }
}
