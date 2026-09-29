<#
.SYNOPSIS
Builds the selected VS2026 solution configuration and migrated x64 drivers.

.EXAMPLE
.\BuildWindows.ps1 -Platform x64 -Configuration Release -Target Rebuild

.EXAMPLE
.\BuildWindows.ps1 -Platform ARM64 -PlanOnly
#>

[CmdletBinding()]
param(
    [ValidateSet("Win32", "x64", "ARM64")]
    [string]$Platform = "x64",

    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",

    [ValidateSet("Build", "Rebuild")]
    [string]$Target = "Build",

    [ValidateRange(1, 64)]
    [int]$MaxCpuCount = 4,

    [string]$MSBuildPath,
    [string]$LogDirectory,

    # ARM64 drivers are already selected in the solution; this only skips extra x64 builds.
    [switch]$SolutionOnly,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$srcDirectory = Split-Path -Parent $PSScriptRoot
if (-not $LogDirectory) {
    $LogDirectory = Join-Path $PSScriptRoot "logs"
}
$solutionPath = Join-Path $srcDirectory "SEVPN.sln"
$solutionLines = Get-Content -LiteralPath $solutionPath
$solutionConfiguration = "$Configuration|$Platform"
if (-not ($solutionLines -match "^\s*$([regex]::Escape($solutionConfiguration)) = ")) {
    throw "The solution does not define $solutionConfiguration. No build was started."
}

$selected = @()
$excluded = @()
foreach ($line in $solutionLines) {
    if ($line -match '^Project\("[^"]+"\) = "([^"]+)", "([^"]+\.(?:vcxproj|csproj))", "([^"]+)"') {
        $name = $Matches[1]
        $id = $Matches[3]
        $mapping = [regex]::Escape("$id.$solutionConfiguration.Build.0")
        if ($solutionLines -match "^\s*$mapping = ") {
            $selected += $name
        }
        else {
            $excluded += $name
        }
    }
}

$steps = @([pscustomobject]@{
    Name = "solution"
    Project = $solutionPath
    Configuration = $Configuration
    Platform = $Platform
})
if ($Platform -eq "x64" -and -not $SolutionOnly) {
    foreach ($driver in @("Neo", "Neo6", "See", "SeLow", "Wfp")) {
        $steps += [pscustomobject]@{
            Name = $driver
            Project = Join-Path $srcDirectory "$driver\$driver.vcxproj"
            Configuration = "Release"
            Platform = "x64"
        }
    }
}

$plan = [pscustomobject]@{
    SolutionConfiguration = $solutionConfiguration
    Target = $Target
    SelectedProjects = $selected
    ExcludedProjects = $excluded
    Steps = $steps
}
if ($PlanOnly) {
    $plan
    return
}

if (-not $MSBuildPath) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw "vswhere.exe was not found. Supply -MSBuildPath for a VS2026 installation."
    }
    $installation = & $vswhere -latest -products * -version "[18.0,19.0)" `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $installation) {
        throw "VS2026 with the C++ build tools was not found. No components were installed."
    }
    $MSBuildPath = Join-Path $installation "MSBuild\Current\Bin\MSBuild.exe"
}
$MSBuildPath = (Resolve-Path -LiteralPath $MSBuildPath).Path
$msbuildVersion = (Get-Item -LiteralPath $MSBuildPath).VersionInfo
if ($msbuildVersion.FileMajorPart -ne 18) {
    throw "VS2026 MSBuild 18 is required, not $($msbuildVersion.FileVersion)."
}
foreach ($library in @("libeay32.lib", "ssleay32.lib", "zlib.lib")) {
    $path = Join-Path $PSScriptRoot "Library\${Platform}_Release\$library"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Dependency library is missing: $path. See README-VS2026.md."
    }
}

$runName = "{0}-{1}-{2}-{3}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $Platform, `
    $Configuration, ([guid]::NewGuid().ToString("N").Substring(0, 8))
$runDirectory = Join-Path ([IO.Path]::GetFullPath($LogDirectory)) $runName
$summaryPath = Join-Path $runDirectory "summary.json"
$summary = [ordered]@{
    StartedAt = (Get-Date).ToString("o")
    Completed = $false
    MSBuildPath = $MSBuildPath
    MSBuildVersion = $msbuildVersion.FileVersion
    Plan = $plan
    Results = @()
    Artifacts = @()
    Failure = $null
}

function Write-BuildSummary {
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}

function Get-BinaryArtifact {
    param([string]$Path, [string]$Kind = "Application")

    $expectedMachine = @{ Win32 = 0x14c; x64 = 0x8664; ARM64 = 0xaa64 }[$Platform]
    $reader = New-Object IO.BinaryReader([IO.File]::OpenRead($Path))
    try {
        if ($reader.BaseStream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) {
            throw "Not a PE binary: $Path"
        }
        $reader.BaseStream.Position = 0x3c
        $offset = $reader.ReadInt32()
        if ($offset -lt 0 -or $offset + 6 -gt $reader.BaseStream.Length) {
            throw "Invalid PE header: $Path"
        }
        $reader.BaseStream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne $expectedMachine) {
            throw "Expected a $Platform PE binary: $Path"
        }
        $reader.BaseStream.Position = 0
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $hash = [BitConverter]::ToString($sha256.ComputeHash($reader.BaseStream)).Replace("-", "")
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $reader.Dispose()
    }
    [pscustomobject]@{
        Path = $Path
        Kind = $Kind
        Machine = ("0x{0:x4}" -f $expectedMachine)
        SHA256 = $hash
    }
}

# The checkout shares host-tool and resource outputs across configurations.
$lockDirectory = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
$lockPath = Join-Path $lockDirectory "windows-build.lock"
try {
    $buildLock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
}
catch [IO.IOException] {
    throw "Cannot acquire the checkout build lock: $lockPath. Another Windows build may be running. No build was started."
}
try {
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    Write-Host "Building $solutionConfiguration with MSBuild $($msbuildVersion.FileVersion)"
    Write-Host "Selected: $($selected -join ', ')"
    Write-Host "Not selected by solution: $($excluded -join ', ')"
    Write-Host "Logs: $runDirectory"
    Write-BuildSummary
    foreach ($step in $steps) {
        $result = [ordered]@{
            Name = $step.Name
            Configuration = $step.Configuration
            Platform = $step.Platform
            Log = Join-Path $runDirectory "$($step.Name).log"
            BinaryLog = Join-Path $runDirectory "$($step.Name).binlog"
            ExitCode = $null
        }
        $summary.Results += $result
        Write-BuildSummary
        Write-Host "Building $($step.Name) ($($step.Configuration)|$($step.Platform))"
        $arguments = @(
            $step.Project, "/t:$Target", "/p:Configuration=$($step.Configuration)",
            "/p:Platform=$($step.Platform)", "/m:$MaxCpuCount", "/nr:false", "/nologo",
            "/clp:ErrorsOnly;Summary", "/flp:LogFile=$($result.Log);Verbosity=normal;Encoding=UTF-8",
            "/bl:$($result.BinaryLog);ProjectImports=None"
        )
        & $MSBuildPath @arguments
        $result.ExitCode = $LASTEXITCODE
        Write-BuildSummary
        if ($result.ExitCode -ne 0) {
            throw "Build failed: $($step.Name), exit code $($result.ExitCode). Log: $($result.Log)"
        }
    }

    $suffix = @{ Win32 = ""; x64 = "_x64"; ARM64 = "_arm64" }[$Platform]
    $applications = @("vpncmd")
    if ($Platform -ne "ARM64") {
        $applications += @("vpnserver", "vpnclient", "vpncmgr")
    }
    foreach ($application in $applications) {
        $applicationDirectory = Join-Path $srcDirectory "bin"
        if ($Configuration -eq "Debug") {
            $applicationDirectory = Join-Path $applicationDirectory "Debug\$Platform"
        }
        $path = Join-Path $applicationDirectory "$application$suffix.exe"
        $summary.Artifacts += Get-BinaryArtifact -Path $path
    }
    $driverNames = @{
        Neo = "Neo_x64.sys"
        Neo6 = "Neo6_${Platform}_unsigned.sys"
        See = "See_x64.sys"
        SeLow = "SeLow_${Platform}_unsigned.sys"
        Wfp = "pxwfp_${Platform}_unsigned.sys"
    }
    $drivers = @()
    if ($Platform -eq "x64" -and -not $SolutionOnly) {
        $drivers = @("Neo", "Neo6", "See", "SeLow", "Wfp")
    }
    elseif ($Platform -eq "ARM64") {
        $drivers = @("Neo6", "SeLow", "Wfp")
    }
    foreach ($driver in $drivers) {
        $path = Join-Path $srcDirectory "BuiltDriverPackages\$driver\$($Platform.ToLowerInvariant())\$($driverNames[$driver])"
        $summary.Artifacts += Get-BinaryArtifact -Path $path -Kind "Driver"
    }
    $summary.Completed = $true
    Write-Host "Build and application architecture checks succeeded. Summary: $summaryPath"
}
catch {
    $summary.Failure = $_.Exception.Message
    throw
}
finally {
    try {
        if (Test-Path -LiteralPath $runDirectory -PathType Container) {
            $summary.FinishedAt = (Get-Date).ToString("o")
            Write-BuildSummary
        }
    }
    finally {
        $buildLock.Dispose()
    }
}
