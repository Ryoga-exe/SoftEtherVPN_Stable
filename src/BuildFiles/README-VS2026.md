# Windows Builds With Visual Studio 2026

## Prerequisites

- Visual Studio 2026 (MSBuild 18, v145) with desktop C++ build tools.
- The ARM64 C++ build tools when targeting ARM64.
- Windows SDK and WDK 10.0.26100.0 for the migrated drivers. Their versions
  must match. The scripts do not install or update these components.
- The existing .NET Framework 2.0/3.5 support required by BuildUtil.
- Matching static dependency libraries in `Library/<Platform>_Release`.

The installed WDK supplies `Microsoft.DriverKit.Build.Tasks.17.0.dll`, not an
18.0 assembly. `src/DriverBuild.props` selects VS17 task compatibility only for
the WDK toolset. It does not switch application projects from v145 to v143.
Keep this compatibility setting until a replacement WDK has been verified.

## Entry Point

From the repository root, run:

```powershell
.\src\BuildAll.cmd -Platform x64 -Configuration Release -Target Rebuild
.\src\BuildAll.cmd -Platform Win32 -Configuration Release -Target Rebuild
.\src\BuildAll.cmd -Platform ARM64 -Configuration Release -Target Rebuild
```

`BuildAll.cmd` now wraps `BuildWindows.ps1`; it no longer invokes the legacy
interactive `BuildUtil /CMD:All` release/packaging workflow. The default is an
incremental Release x64 build. No Native Tools prompt is needed for this entry
point. The script discovers a VS2026 installation with `vswhere`, or accepts
`-MSBuildPath` for an explicit MSBuild 18 executable.

Inspect the build plan without compiling:

```powershell
.\src\BuildFiles\BuildWindows.ps1 -Platform ARM64 -PlanOnly | Format-List
```

The entry point holds an exclusive checkout-wide lock and rejects a second
invocation until the first finishes. Do not run an IDE or direct MSBuild build
against that checkout at the same time; those do not use the script lock. Architectures
share `src/bin`, including the resource-only `PenCore.dll`. Release applications
use `src/bin`; Debug applications use `src/bin/Debug/<Platform>`. Debug runtime
resources still need to be staged separately before execution.

## Scope And Evidence

| Configuration | Solution scope | Additional default builds |
| --- | --- | --- |
| Release/Debug Win32 | Selected desktop projects, including vpnweb | None |
| Release/Debug x64 | Selected desktop projects | Release x64 Neo, Neo6, See, SeLow, Wfp |
| Release ARM64 | Mayaqua, Cedar, PenCore, vpncmd, Neo6, SeLow, Wfp, BuildUtil | None |
| Debug ARM64 | Not defined | Rejected before building |

`-SolutionOnly` skips the additional x64 driver builds. It does not remove
drivers selected by the ARM64 solution configuration. Legacy Win32 drivers
still depend on the old WDK; the installed WDK has no x86 kernel libraries.
VGate and unported ARM64 application projects are not included.

Every invocation saves text logs, binary logs, and `summary.json` under a unique
`src/BuildFiles/logs` directory. The summary records the exact configuration,
selected and excluded projects, MSBuild version, individual exit codes, and
SHA-256 hashes/PE architectures of the principal application and driver outputs. A failed
step stops the build and leaves `Completed` false. Success is evidence of
compilation/linking, not a claim that every solution project or runtime feature
has been verified.

BuildUtil is a host tool built as Release/AnyCPU before native consumers. WDK
projects use an explicit solution dependency and a standalone-project fallback
because WDK packaging treats all ProjectReference items as driver inputs.
MSBuild's Copy task publishes BuildUtil.exe and propagates copy failures.

Run the self-contained build checks with an explicit MSBuild path:

```powershell
.\src\BuildFiles\TestWindowsBuild.ps1 -MSBuildPath "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe"
```

The checks intentionally provoke a Copy task failure in an isolated log
directory. They do not install services or drivers.
Run these checks when no entry-point build is active.

## Verification On 2026-09-29

The entry point was exercised with MSBuild 18.7.8.30822 and the installed
SDK/WDK 10.0.26100.0. Release Win32, x64, and ARM64 rebuilds succeeded within
the scope above. The x64 run also rebuilt the five migrated drivers separately.
Debug Win32 and x64 solution rebuilds succeeded, but with the CRT warning
described below; these are not a declaration of complete Debug support.

The self-contained checks passed under Windows PowerShell 5.1 and PowerShell 7. Argument
rejection, the checkout lock, Debug output-property consistency, and expected
BuildUtil Copy failure were checked. PE machine checks passed for the principal
application outputs and the drivers included by the entry point. No VPN
connection, service installation, driver installation, or ARM64 runtime test
was performed.

vpnweb's MIDL outputs now live in its configuration-specific intermediate
directory. Rebuilding no longer rewrites the tracked generated headers/sources.

## Remaining Work

- Debug can compile/link using the existing Release dependency archives, but
  LNK4098 reports CRT mixing. Rebuild dependencies for the correct Debug CRT and
  select those libraries before declaring Debug support complete. Do not suppress
  the warning or use NODEFAULTLIB to hide the mismatch.
  Review Debug mappings for Release-only supporting projects such as SeeDll too.
- Desktop dependency libraries currently produce missing OpenSSL PDB warnings
  (LNK4099). Rebuild them with embedded debug information or ship the matching
  PDBs rather than suppressing the warning.
- Audit existing x64 Debug pointer-size warnings (C4311/C4312) and the network
  structure/format warnings. Successful linking is not runtime validation.
- Verify actual VPN traffic, services, GUI startup, and local bridging separately.
- ARM64 vpnserver, vpnclient, GUI tools, and driver installation are not yet
  ported. Native OS architecture detection and driver-path selection need work.
- Generated driver binaries are build/test artifacts, not deployable production
  packages. INF/CAT creation, hamcore integration, and signing remain separate.
  Building does not install drivers, trust test certificates, or change boot
  signing settings. Driver installation must be performed explicitly by the user.
- Update dependencies separately from the toolchain migration: scripts currently
  pin OpenSSL 3.0.9 and zlib 1.2.11. OpenSSL 3.0 is no longer normally supported;
  evaluate the latest 3.5 LTS patch and current zlib before production use.

Official dependency references:
[OpenSSL release policy](https://openssl-library.org/policies/releasestrat/)
and [zlib releases](https://www.zlib.net/).
