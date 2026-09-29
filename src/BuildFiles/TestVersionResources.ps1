<#
.SYNOPSIS
Checks parallel version-resource generation, spaced output paths, and locked-output failures.
#>
[CmdletBinding()]
param([string]$BuildUtilPath)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if (-not $BuildUtilPath) {
    $BuildUtilPath = Join-Path (Split-Path -Parent $PSScriptRoot) "bin\BuildUtil.exe"
}
$BuildUtilPath = (Resolve-Path -LiteralPath $BuildUtilPath).Path
$scratch = Join-Path $PSScriptRoot ("logs\version resources-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $scratch | Out-Null
$jobs = @()
try {
    foreach ($index in 1..12) {
        $target = "sample $index.exe"
        $resource = Join-Path $scratch "nested folder\sample $index.res"
        $process = New-Object Diagnostics.Process
        $process.StartInfo.FileName = $BuildUtilPath
        $process.StartInfo.Arguments = "/CMD:GenerateVersionResource `"$target`" /OUT:`"$resource`""
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        [void]$process.Start()
        $jobs += [pscustomobject]@{ Process = $process; Target = $target; Resource = $resource }
    }
    foreach ($job in $jobs) {
        $stdout = $job.Process.StandardOutput.ReadToEnd()
        $stderr = $job.Process.StandardError.ReadToEnd()
        $job.Process.WaitForExit()
        if ($job.Process.ExitCode -ne 0) { throw "Resource generation failed: $stdout $stderr" }
        $bytes = [IO.File]::ReadAllBytes($job.Resource)
        if ($bytes.Length -le 32 -or [Text.Encoding]::Unicode.GetString($bytes) -notlike "*$($job.Target)*") {
            throw "Wrong or empty version resource: $($job.Resource)"
        }
    }
}
finally {
    foreach ($job in $jobs) {
        if (-not $job.Process.HasExited) { $job.Process.WaitForExit() }
        $job.Process.Dispose()
    }
}

# An unwritable output must fail, never silently reuse a previous resource.
$resource = $jobs[0].Resource
$original = [Convert]::ToBase64String([IO.File]::ReadAllBytes($resource))
$heldLock = [IO.File]::Open($resource, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    & $BuildUtilPath /CMD:GenerateVersionResource "locked output.exe" "/OUT:$resource" `
        *> (Join-Path $scratch "expected-failure.log")
    if ($LASTEXITCODE -eq 0) { throw "Resource generation unexpectedly succeeded with a locked output." }
}
finally { $heldLock.Dispose() }
if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($resource)) -ne $original) {
    throw "A failed invocation modified the locked resource."
}
Write-Host "Version-resource checks passed: 12 parallel outputs, spaced paths, and the expected locked-output failure."
