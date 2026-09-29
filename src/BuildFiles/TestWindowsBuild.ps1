<#
.SYNOPSIS
Checks build plans, rejected inputs, and BuildUtil publication failure handling.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$MSBuildPath)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$buildScript = Join-Path $PSScriptRoot "BuildWindows.ps1"
$srcDirectory = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Rejected {
    param([scriptblock]$Action, [string]$MessagePattern)
    $rejected = $false
    try {
        & $Action | Out-Null
    }
    catch {
        if (($_.Exception.Message + " " + $_.FullyQualifiedErrorId) -notmatch $MessagePattern) {
            throw
        }
        $rejected = $true
    }
    Assert-True $rejected "Expected the input to be rejected: $MessagePattern"
}

$x64 = & $buildScript -Platform x64 -PlanOnly
Assert-True ($x64.Steps.Count -eq 6) "x64 must build the solution and five drivers."
Assert-True ($x64.SelectedProjects -contains "vpnserver") "x64 vpnserver was not selected."
Assert-True ($x64.ExcludedProjects -contains "Neo6") "Neo6 must be tracked as a separate x64 build."
$solutionOnly = & $buildScript -Platform x64 -SolutionOnly -PlanOnly
Assert-True ($solutionOnly.Steps.Count -eq 1) "SolutionOnly must omit the extra driver builds."
$debug = & $buildScript -Platform x64 -Configuration Debug -PlanOnly
Assert-True ($debug.Steps[1].Configuration -eq "Release") "Drivers only have Release configurations."
Assert-True ($debug.DependencyDirectory -eq (Join-Path $PSScriptRoot "Library\x64_Debug")) "Debug preflight must not use Release dependencies."
$arm64 = & $buildScript -Platform ARM64 -PlanOnly
Assert-True ($arm64.Steps.Count -eq 1) "ARM64 drivers are already part of the solution."
Assert-True ($arm64.SelectedProjects.Count -eq 8) "ARM64 must select seven native projects and BuildUtil."
Assert-True ($arm64.SelectedProjects -contains "Neo6") "ARM64 Neo6 was not selected."
Assert-True ($arm64.ExcludedProjects -contains "vpnclient") "Unported ARM64 applications must be visible."
$win32 = & $buildScript -Platform Win32 -PlanOnly
Assert-True ($win32.SelectedProjects -contains "vpnweb") "Win32 vpnweb was not selected."
Assert-True ($win32.ExcludedProjects -contains "Neo") "Legacy x86 driver builds are not supported."
Assert-Rejected { & $buildScript -Platform ARM64 -Configuration Debug -PlanOnly } "does not define"
Assert-Rejected { & $buildScript -Platform x64 -MaxCpuCount 0 -PlanOnly } "ParameterArgumentValidationError"
Assert-Rejected { & $buildScript -MSBuildPath (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\MSBuild.exe") } "MSBuild 18 is required"
& (Join-Path $PSScriptRoot "TestDependencyBuild.ps1") -PlansOnly

foreach ($platform in @("Win32", "x64")) {
    foreach ($application in @("vpncmd", "vpnserver", "vpnclient")) {
        $projectPath = Join-Path $srcDirectory "$application\$application.vcxproj"
        $properties = & $MSBuildPath $projectPath /p:Configuration=Debug "/p:Platform=$platform" `
            /nologo -getProperty:OutDir,TargetPath,TargetDir
        Assert-True ($LASTEXITCODE -eq 0) "Property evaluation failed for $application ($platform)."
        $evaluated = ($properties -join "`n" | ConvertFrom-Json).Properties
        $expectedDirectory = Join-Path $srcDirectory "bin\Debug\$platform\"
        Assert-True ($evaluated.OutDir -eq $expectedDirectory) "Incorrect Debug OutDir for $application."
        Assert-True ($evaluated.TargetDir -eq $expectedDirectory) "Stale Debug TargetDir for $application."
        Assert-True ($evaluated.TargetPath.StartsWith($expectedDirectory)) "Debug TargetPath would overwrite Release."
    }
}

$lockDirectory = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
$heldLock = [IO.File]::Open((Join-Path $lockDirectory "windows-build.lock"),
    [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    Assert-Rejected { & $buildScript -MSBuildPath $MSBuildPath } "checkout build lock"
}
finally {
    $heldLock.Dispose()
}

$hostProject = Join-Path $srcDirectory "BuildUtil\BuildUtil.csproj"
& $MSBuildPath $hostProject /t:Build /p:Configuration=Release /p:Platform=AnyCPU `
    /nr:false /nologo "/clp:ErrorsOnly;Summary"
Assert-True ($LASTEXITCODE -eq 0) "BuildUtil could not be prepared for resource-generation tests."
& (Join-Path $PSScriptRoot "TestVersionResources.ps1")

# An unwritable destination must fail instead of silently leaving a stale executable.
$scratch = Join-Path $PSScriptRoot ("logs\publish-test-" + [guid]::NewGuid().ToString("N"))
$output = Join-Path $scratch "bin"
$intermediate = Join-Path $scratch "obj"
New-Item -ItemType Directory -Path (Join-Path $output "BuildUtil.exe"), $intermediate | Out-Null
$project = Join-Path (Split-Path -Parent $PSScriptRoot) "BuildUtil\BuildUtil.csproj"
$log = Join-Path $scratch "failure.log"
& $MSBuildPath $project /t:Build /p:Configuration=Release /p:Platform=AnyCPU `
    "/p:OutputPath=$output\" "/p:IntermediateOutputPath=$intermediate\" `
    /nr:false /nologo "/clp:ErrorsOnly;Summary" "/flp:LogFile=$log;Verbosity=normal;Encoding=UTF-8"
Assert-True ($LASTEXITCODE -ne 0) "Publishing to a directory unexpectedly succeeded."
Assert-True ([bool](Select-String -LiteralPath $log -Pattern "error MSB3024")) `
    "The build did not fail at the expected Copy task."
Write-Host "Windows build checks passed, including the expected publication failure."
