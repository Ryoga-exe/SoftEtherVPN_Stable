<#
.SYNOPSIS
Checks dependency configuration selection, archive hashes, machines, CRTs, and PDB independence.
#>
[CmdletBinding()]
param([string]$DumpBinPath, [switch]$PlansOnly)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
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

$plans = @()
foreach ($platform in @("Win32", "x64", "ARM64")) {
    foreach ($configuration in @("Release", "Debug")) {
        $parameters = @{ Configuration = $configuration; OpenSslSource = "unused"; ZlibSource = "unused"; PlanOnly = $true }
        $script = "BuildArm64Dependencies.ps1"
        if ($platform -ne "ARM64") {
            $script = "BuildDesktopDependencies.ps1"
            $parameters.Platform = $platform
        }
        $plan = & (Join-Path $PSScriptRoot $script) @parameters
        $expectedRuntime = if ($configuration -eq "Debug") { "MTd" } else { "MT" }
        $expectedDirectory = Join-Path $PSScriptRoot "Library\${platform}_$configuration"
        Assert-True ($plan.Platform -eq $platform -and $plan.Configuration -eq $configuration) "Wrapper lost configuration arguments."
        Assert-True ($plan.OutputDirectory -eq $expectedDirectory) "Dependencies would overwrite another configuration."
        Assert-True ($plan.RuntimeLibrary -eq $expectedRuntime) "Incorrect dependency CRT."
        Assert-True ($plan.DebugInformation -eq "Z7" -and $plan.ZlibCFlags -match "-Z7") "Dependency symbols must be embedded."
        Assert-True ($plan.ZlibCFlags -match "-$expectedRuntime(?: |$)") "zlib CRT differs from OpenSSL."
        if ($platform -ne "ARM64" -or $configuration -ne "Debug") {
            $solutionPlan = & (Join-Path $PSScriptRoot "BuildWindows.ps1") -Platform $platform -Configuration $configuration -PlanOnly
            Assert-True ($solutionPlan.DependencyDirectory -eq $expectedDirectory) "Solution preflight selects the wrong dependencies."
            $plans += $plan
        }
    }
}

[xml]$mayaqua = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) "Mayaqua\Mayaqua.vcxproj") -Raw
foreach ($group in $mayaqua.Project.ItemDefinitionGroup) {
    Assert-True ($group.Lib.AdditionalLibraryDirectories -eq
        '$(SolutionDir)BuildFiles\Library\$(Platform)_$(Configuration);%(AdditionalLibraryDirectories)') `
        "Mayaqua still uses configuration-independent dependency libraries."
}

if ($PlansOnly) {
    Write-Host "Dependency plans and project configuration checks passed."
    return
}
if (-not $DumpBinPath) { $DumpBinPath = (Get-Command dumpbin.exe).Source }
$DumpBinPath = (Resolve-Path -LiteralPath $DumpBinPath).Path
$machines = @{ Win32 = "14C"; x64 = "8664"; ARM64 = "AA64" }
foreach ($plan in $plans) {
    $metadataPath = Join-Path $plan.OutputDirectory "build-info.json"
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    Assert-True ($metadata.SchemaVersion -eq 1) "Unsupported dependency manifest: $metadataPath"
    Assert-True ($metadata.Platform -eq $plan.Platform -and $metadata.Configuration -eq $plan.Configuration) "Manifest configuration mismatch."
    Assert-True ($metadata.RuntimeLibrary -eq $plan.RuntimeLibrary -and $metadata.DebugInformation -eq "Z7") "Manifest CRT/debug settings mismatch."
    Assert-True ($metadata.OpenSSL -eq "3.0.9" -and $metadata.Zlib -eq "1.2.11") "Dependencies no longer match the pinned headers."
    Assert-True ($metadata.OpenSslConfigSHA256 -eq (Get-Sha256 (Join-Path $PSScriptRoot "OpenSslStatic.conf"))) "Archives need rebuilding after an OpenSSL configuration change."
    Assert-True ($metadata.Archives.Count -eq 3) "Three dependency archives are required."
    foreach ($name in @("libeay32.lib", "ssleay32.lib", "zlib.lib")) {
        $archive = Join-Path $plan.OutputDirectory $name
        $record = @($metadata.Archives | Where-Object Name -eq $name)
        Assert-True ($record.Count -eq 1) "Missing or duplicate archive record: $name"
        Assert-True ((Get-Sha256 $archive) -eq $record[0].SHA256) "Archive differs from the manifest: $archive"
        $headers = & $DumpBinPath /nologo /headers $archive
        Assert-True ($LASTEXITCODE -eq 0) "Could not inspect archive headers: $archive"
        $matches = [regex]::Matches(($headers -join "`n"), '(?im)^\s*([0-9a-f]{3,4}) machine \(')
        Assert-True ($matches.Count -gt 0) "No COFF machine headers found: $archive"
        foreach ($match in $matches) {
            Assert-True ($match.Groups[1].Value -eq $machines[$plan.Platform]) "Wrong machine in $archive"
        }
        if ($name -eq "zlib.lib") {
            $directives = & $DumpBinPath /nologo /directives $archive
            Assert-True ($LASTEXITCODE -eq 0) "Could not inspect zlib CRT directives."
            $crtNames = [regex]::Matches(($directives -join "`n"), '(?i)DEFAULTLIB:"?(LIBCMTD|LIBCMT|MSVCRTD|MSVCRT)\b')
            Assert-True ($crtNames.Count -gt 0) "zlib has no detectable CRT directives."
            $expected = if ($plan.Configuration -eq "Debug") { "LIBCMTD" } else { "LIBCMT" }
            foreach ($crt in $crtNames) {
                Assert-True ($crt.Groups[1].Value -eq $expected) "zlib references the wrong CRT: $archive"
            }
        }
        else {
            $contents = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($archive))
            Assert-True ($contents -notmatch 'ossl_static\.pdb') "OpenSSL still depends on a discarded compiler PDB: $archive"
            $contents = $null
        }
    }
    Write-Host "Verified $($plan.Platform) $($plan.Configuration) archives."
}
Write-Host "Dependency build checks passed."
