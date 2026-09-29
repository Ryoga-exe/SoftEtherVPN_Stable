<#
.SYNOPSIS
Links a dependency probe and runs it only on a compatible host. No VPN or OS settings are changed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet("Win32", "x64", "ARM64")][string]$Platform,
    [ValidateSet("Release", "Debug")][string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$architectures = @{ Win32 = "x86"; x64 = "x64"; ARM64 = "arm64" }
if ($env:VSCMD_ARG_TGT_ARCH -ne $architectures[$Platform] -or $env:VisualStudioVersion -notlike "18.*") {
    throw "Use a VS2026 $($architectures[$Platform]) Native Tools environment."
}
$sourceDirectory = Split-Path -Parent $PSScriptRoot
$libraryDirectory = Join-Path $PSScriptRoot "Library\${Platform}_$Configuration"
$output = Join-Path $PSScriptRoot ("logs\dependency-probe-${Platform}-${Configuration}-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $output | Out-Null
$executable = Join-Path $output "probe.exe"
$runtime = if ($Configuration -eq "Debug") { "/MTd" } else { "/MT" }
$arguments = @(
    "/nologo", "/W3", "/WX", $runtime, "/Z7", "/I$(Join-Path $sourceDirectory 'Mayaqua\win32_inc')",
    "/I$(Join-Path $sourceDirectory 'Mayaqua')",
    (Join-Path $PSScriptRoot "DependencyProbe.c"), "/Fo$(Join-Path $output 'probe.obj')", "/Fe$executable",
    (Join-Path $libraryDirectory "ssleay32.lib"), (Join-Path $libraryDirectory "libeay32.lib"),
    (Join-Path $libraryDirectory "zlib.lib"), "/link", "/WX", "/DEBUG",
    "ws2_32.lib", "gdi32.lib", "advapi32.lib", "crypt32.lib", "user32.lib"
)
& cl.exe @arguments
if ($LASTEXITCODE -ne 0) { throw "Dependency probe compilation/linking failed: $Platform $Configuration" }
$hostArchitecture = $env:PROCESSOR_ARCHITEW6432
if (-not $hostArchitecture) { $hostArchitecture = $env:PROCESSOR_ARCHITECTURE }
$compatible = $hostArchitecture -ieq $architectures[$Platform] -or
    ($hostArchitecture -ieq "AMD64" -and $Platform -in @("Win32", "x64"))
if ($compatible) {
    & $executable
    if ($LASTEXITCODE -ne 0) { throw "Dependency runtime probe failed with exit code $LASTEXITCODE." }
}
else {
    Write-Host "Probe linked, but execution was skipped on $hostArchitecture. Run this test on a compatible $Platform host."
}
