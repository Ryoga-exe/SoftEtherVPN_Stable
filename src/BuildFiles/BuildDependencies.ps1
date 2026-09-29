<#
.SYNOPSIS
Builds pinned OpenSSL and zlib archives with nmake in a VS2026 Native Tools environment.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Win32", "x64", "ARM64")]
    [string]$Platform,

    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",

    [Parameter(Mandatory = $true)][string]$OpenSslSource,
    [Parameter(Mandatory = $true)][string]$ZlibSource,
    [string]$WorkDirectory = (Join-Path $env:TEMP "SoftEtherVPN-deps"),
    [switch]$KeepWorkDirectory,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$architectures = @{ Win32 = "x86"; x64 = "x64"; ARM64 = "arm64" }
$targets = @{ Win32 = "VC-WIN32"; x64 = "VC-WIN64A"; ARM64 = "VC-WIN64-ARM" }
$runtime = if ($Configuration -eq "Debug") { "MTd" } else { "MT" }
$optimization = if ($Configuration -eq "Debug") { "Od" } else { "O2" }
$plan = [pscustomobject]@{
    Platform = $Platform
    Configuration = $Configuration
    TargetArchitecture = $architectures[$Platform]
    OpenSslTarget = "SoftEther-$($targets[$Platform])"
    # Each invocation uses a fresh tree, so incremental header dependency scans are unnecessary.
    OpenSslArguments = @("no-shared", "no-tests", "no-makedepend", "--$($Configuration.ToLowerInvariant())")
    RuntimeLibrary = $runtime
    DebugInformation = "Z7"
    ZlibCFlags = "-nologo -$runtime -W3 -$optimization -Oy- -Z7"
    OutputDirectory = Join-Path $PSScriptRoot "Library\${Platform}_$Configuration"
}
if ($PlanOnly) {
    $plan
    return
}

function Invoke-NativeCommand {
    param([string]$Command, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE`: $Command $($Arguments -join ' ')"
    }
}

function Get-Sha256 {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace("-", "")
    }
    finally {
        $sha256.Dispose()
        $stream.Dispose()
    }
}

if ($env:VSCMD_ARG_TGT_ARCH -ne $plan.TargetArchitecture -or $env:VisualStudioVersion -notlike "18.*") {
    throw "Run this script from a VS2026 $($plan.TargetArchitecture) Native Tools command prompt."
}
foreach ($command in @("cl.exe", "lib.exe", "nmake.exe", "perl.exe")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command was not found in PATH: $command"
    }
}
if ($Platform -ne "ARM64" -and -not (Get-Command nasm.exe -ErrorAction SilentlyContinue)) {
    throw "Required command was not found in PATH: nasm.exe"
}
$compiler = (Get-Command cl.exe).Source
$compilerVersion = (Get-Item -LiteralPath $compiler).VersionInfo.FileVersion
$OpenSslSource = (Resolve-Path -LiteralPath $OpenSslSource).Path
$ZlibSource = (Resolve-Path -LiteralPath $ZlibSource).Path
$openSslVersion = Get-Content -LiteralPath (Join-Path $OpenSslSource "VERSION.dat") -Raw
foreach ($entry in @("MAJOR=3", "MINOR=0", "PATCH=9")) {
    if ($openSslVersion -notmatch "(?m)^$entry\r?$") {
        throw "OpenSSL 3.0.9 source is required; update headers and libraries together before changing this pin."
    }
}
$zlibHeader = Get-Content -LiteralPath (Join-Path $ZlibSource "zlib.h") -Raw
if ($zlibHeader -notmatch '#define\s+ZLIB_VERSION\s+"1\.2\.11"') {
    throw "zlib 1.2.11 source is required; update headers and libraries together before changing this pin."
}

New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
$workRoot = (Resolve-Path -LiteralPath $WorkDirectory).Path
$buildRoot = Join-Path $workRoot ("build-" + [guid]::NewGuid().ToString("N"))
$openSslBuild = Join-Path $buildRoot "openssl"
$zlibBuild = Join-Path $buildRoot "zlib"
$staging = Join-Path $buildRoot "staging"

# Dependency publication must not race a solution build or another dependency build.
$lockDirectory = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
try {
    $buildLock = [IO.File]::Open((Join-Path $lockDirectory "windows-build.lock"),
        [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
}
catch [IO.IOException] {
    throw "Cannot acquire the checkout build lock. Another Windows build may be running."
}
try {
    New-Item -ItemType Directory -Path $openSslBuild, $zlibBuild, $staging | Out-Null
    $openSslConfig = Join-Path $buildRoot "OpenSslStatic.conf"
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "OpenSslStatic.conf") -Destination $openSslConfig
    Write-Host "Building $Platform $Configuration dependencies in $buildRoot"
    Push-Location $openSslBuild
    try {
        $configureArguments = @((Join-Path $OpenSslSource "Configure"),
            "--config=$openSslConfig", $plan.OpenSslTarget) +
            $plan.OpenSslArguments
        Invoke-NativeCommand perl.exe @configureArguments
        Invoke-NativeCommand nmake.exe /NOLOGO build_libs
    }
    finally {
        Pop-Location
    }

    # Never modify the supplied source tree; exclude its Git metadata from the copy.
    Get-ChildItem -LiteralPath $ZlibSource -Force | Where-Object Name -ne ".git" |
        Copy-Item -Destination $zlibBuild -Recurse -Force
    Push-Location $zlibBuild
    try {
        Invoke-NativeCommand nmake.exe /NOLOGO /f win32\Makefile.msc clean
        Invoke-NativeCommand nmake.exe /NOLOGO /f win32\Makefile.msc "CFLAGS=$($plan.ZlibCFlags)" zlib.lib
    }
    finally {
        Pop-Location
    }

    # Publish only after all three archives have built successfully.
    Copy-Item -LiteralPath (Join-Path $openSslBuild "libcrypto.lib") -Destination (Join-Path $staging "libeay32.lib")
    Copy-Item -LiteralPath (Join-Path $openSslBuild "libssl.lib") -Destination (Join-Path $staging "ssleay32.lib")
    Copy-Item -LiteralPath (Join-Path $zlibBuild "zlib.lib") -Destination (Join-Path $staging "zlib.lib")
    $metadata = [ordered]@{
        SchemaVersion = 1
        Platform = $Platform
        Configuration = $Configuration
        OpenSSL = "3.0.9"
        Zlib = "1.2.11"
        CompilerVersion = $compilerVersion
        WindowsSDKVersion = $env:WindowsSDKVersion
        RuntimeLibrary = $runtime
        DebugInformation = "Z7"
        OpenSslTarget = $plan.OpenSslTarget
        OpenSslArguments = $plan.OpenSslArguments
        OpenSslConfigSHA256 = Get-Sha256 $openSslConfig
        ZlibCFlags = $plan.ZlibCFlags
        Archives = @(foreach ($name in @("libeay32.lib", "ssleay32.lib", "zlib.lib")) {
            [ordered]@{ Name = $name; SHA256 = Get-Sha256 (Join-Path $staging $name) }
        })
    }
    $metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $staging "build-info.json") -Encoding UTF8
    New-Item -ItemType Directory -Path $plan.OutputDirectory -Force | Out-Null
    Copy-Item -Path (Join-Path $staging "*") -Destination $plan.OutputDirectory -Force
    Write-Host "Dependencies and build-info.json were written to $($plan.OutputDirectory)"
}
finally {
    try {
        if (-not $KeepWorkDirectory -and (Test-Path -LiteralPath $buildRoot)) {
            $cleanupPath = (Resolve-Path -LiteralPath $buildRoot).Path
            if (-not $cleanupPath.StartsWith($workRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
                (Split-Path -Parent $cleanupPath).TrimEnd('\') -ne $workRoot.TrimEnd('\')) {
                throw "Refusing to remove a build directory outside the resolved work root: $cleanupPath"
            }
            Remove-Item -LiteralPath $cleanupPath -Recurse -Force
        }
    }
    finally {
        $buildLock.Dispose()
    }
}
