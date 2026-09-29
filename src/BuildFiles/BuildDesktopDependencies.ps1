<#
.SYNOPSIS
Builds configuration-matched Win32 or x64 OpenSSL and zlib static libraries.

.EXAMPLE
.\BuildDesktopDependencies.ps1 -Platform x64 -Configuration Debug `
    -OpenSslSource C:\src\openssl-3.0.9 -ZlibSource C:\src\zlib-1.2.11
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Win32", "x64")]
    [string]$Platform,

    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",

    [Parameter(Mandatory = $true)][string]$OpenSslSource,
    [Parameter(Mandatory = $true)][string]$ZlibSource,
    [string]$WorkDirectory = (Join-Path $env:TEMP "SoftEtherVPN-desktop-deps"),
    [switch]$KeepWorkDirectory,
    [switch]$PlanOnly
)

$arguments = @{} + $PSBoundParameters
$arguments.WorkDirectory = $WorkDirectory
& (Join-Path $PSScriptRoot "BuildDependencies.ps1") @arguments
