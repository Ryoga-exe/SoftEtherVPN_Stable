<#
.SYNOPSIS
Builds configuration-matched ARM64 OpenSSL and zlib static libraries.

.EXAMPLE
.\BuildArm64Dependencies.ps1 -Configuration Release `
    -OpenSslSource C:\src\openssl-3.0.9 -ZlibSource C:\src\zlib-1.2.11
#>
[CmdletBinding()]
param(
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",

    [Parameter(Mandatory = $true)][string]$OpenSslSource,
    [Parameter(Mandatory = $true)][string]$ZlibSource,
    [string]$WorkDirectory = (Join-Path $env:TEMP "SoftEtherVPN-arm64-deps"),
    [switch]$KeepWorkDirectory,
    [switch]$PlanOnly
)

$arguments = @{} + $PSBoundParameters
$arguments.WorkDirectory = $WorkDirectory
& (Join-Path $PSScriptRoot "BuildDependencies.ps1") -Platform ARM64 @arguments
