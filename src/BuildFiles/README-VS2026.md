# Windows Builds With Visual Studio 2026

## Prerequisites

- Visual Studio 2026 (MSBuild 18, v145) with desktop C++ build tools.
- The ARM64 C++ build tools when targeting ARM64.
- Windows SDK and WDK 10.0.26100.0 for the migrated drivers. Their versions
  must match. The scripts do not install or update these components.
- The existing .NET Framework 2.0/3.5 support required by BuildUtil.
- Matching static dependency libraries in `Library/<Platform>_<Configuration>`.

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
step stops the build and leaves `Completed` false. The entry point also rejects
LNK4098 (CRT conflicts) and LNK4099 (missing compiler PDBs), even if MSBuild
otherwise returns success. Other existing warnings are not suppressed. Success is evidence of
compilation/linking, not a claim that every solution project or runtime feature
has been verified.

BuildUtil is a host tool built as Release/AnyCPU before native consumers. WDK
projects use an explicit solution dependency and a standalone-project fallback
because WDK packaging treats all ProjectReference items as driver inputs.
MSBuild's Copy task publishes BuildUtil.exe and propagates copy failures.
Version-resource generation now uses rc.exe's
[`/fo` output option](https://learn.microsoft.com/en-us/windows/win32/menurc/using-rc-the-rc-command-line-)
to write the final `.res` directly. This removes the temporary `.res` read/copy
that intermittently failed with a sharing violation; a compiler/output failure
still fails the build rather than reusing a stale resource.

Run the self-contained build checks with an explicit MSBuild path:

```powershell
.\src\BuildFiles\TestWindowsBuild.ps1 -MSBuildPath "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe"
```

The checks intentionally provoke a Copy task failure in an isolated log
directory. They also check 12 parallel resource-generation processes, spaced
output paths, and rejection of locked resource outputs. They do not install services or drivers.
Run these checks when no entry-point build is active.

## Dependency Builds

The desktop and ARM64 wrappers use the same `BuildDependencies.ps1` recipe.
Release archives use `/MT`; Debug archives use `/MTd`. `OpenSslStatic.conf`
inherits the upstream architecture settings but replaces its static-library
CRT/debug flags with the matching CRT and `/Z7`. This preserves compiler debug
information inside the archive instead of referencing a discarded
`ossl_static.pdb`. zlib also uses the matching CRT and `/Z7`.

Use an appropriate **VS2026 Native Tools** environment: x86 for Win32, x64 for
x64, or the x64-to-ARM64 cross tools for ARM64 on an x64 host. Perl and NASM must
be in PATH (NASM is needed only for Win32/x64). The scripts still use `nmake`;
no additional build system or component installation is required.

For example, from the repository root in an x64 Native Tools prompt:

```powershell
.\src\BuildFiles\BuildDesktopDependencies.ps1 -Platform x64 -Configuration Release -OpenSslSource C:\src\openssl-3.0.9 -ZlibSource C:\src\zlib-1.2.11
.\src\BuildFiles\BuildDesktopDependencies.ps1 -Platform x64 -Configuration Debug -OpenSslSource C:\src\openssl-3.0.9 -ZlibSource C:\src\zlib-1.2.11
.\src\BuildFiles\TestDependencyRuntime.ps1 -Platform x64 -Configuration Debug
```

Use `-Platform Win32` in the x86 tools environment. For ARM64, use
`BuildArm64Dependencies.ps1` with the same source and configuration parameters.
Building ARM64 Debug dependencies does not add a Debug ARM64 solution
configuration. Keep source and work directories short: some Perl/MSVC tools
still fail when full paths approach the Windows legacy path-length limit.

The pinned source tags are `openssl-3.0.9` in
[openssl/openssl](https://github.com/openssl/openssl/tree/openssl-3.0.9) and
`v1.2.11` in [madler/zlib](https://github.com/madler/zlib/tree/v1.2.11).
They match the checked-in headers; this is a toolchain baseline, not an update
to current production dependencies. Clone with `core.autocrlf=false` or use
the corresponding upstream source archives. CRLF version metadata is also accepted.

Every invocation builds in a new temporary tree and snapshots the OpenSSL
configuration before running nmake. `no-makedepend` avoids redundant incremental
header scans in that fresh tree. The three archives are copied to
`Library/<Platform>_<Configuration>` only after both dependency builds succeed.
`build-info.json` records compiler/SDK versions, CRT/debug settings, configuration
arguments, and archive SHA-256 hashes. This is not an atomic multi-file
filesystem transaction. The same checkout lock excludes simultaneous scripted
solution/dependency builds; do not build in the IDE at the same time.
`-KeepWorkDirectory` retains the intermediate tree for diagnosis.

Check all five supported solution dependency sets from an x64 tools prompt:

```powershell
.\src\BuildFiles\TestDependencyBuild.ps1
```

`-DumpBinPath` can supply an explicit VS2026 dumpbin outside a tools prompt.
`-PlansOnly` requires no tools or archives. The full check verifies configuration
selection, hashes, COFF machine types, zlib CRT directives, and absence of
OpenSSL's discarded PDB reference. `TestDependencyRuntime.ps1` compiles and
links a small probe with warnings treated as errors. It checks the header/runtime
versions, creation of a TLS context, a SHA-256 known answer, and a zlib round-trip
on compatible hosts. On an x64 host the ARM64 probe is linked but not executed;
run it on the ARM64 machine once available. No probe changes VPN, service,
driver, certificate, boot, or external OpenSSL configuration settings.

## Verification On 2026-09-29

The entry point was exercised with MSBuild 18.7.8.30822 and the installed
SDK/WDK 10.0.26100.0. Release Win32, x64, and ARM64 rebuilds succeeded within
the scope above. The x64 run also rebuilt the five migrated drivers separately.
After rebuilding configuration-matched dependencies, Debug Win32 and x64
solution rebuilds also succeeded. All five runs recorded zero LNK4098/LNK4099
warnings without suppressing them. Existing compiler/other linker warnings remain.

| Configuration | Build steps | Verified principal PE artifacts | LNK4098/LNK4099 |
| --- | --- | --- | --- |
| Debug x64 | Solution | 4 applications | 0 |
| Debug Win32 | Solution | 4 applications | 0 |
| Release x64 | Solution plus 5 drivers | 4 applications and 5 drivers | 0 |
| Release Win32 | Solution | 4 applications | 0 |
| Release ARM64 | Solution | vpncmd and 3 drivers | 0 |

Successful run summaries are retained in `logs` under these directory names:

```text
20260929-140543-x64-Debug-47db52b6
20260929-140718-Win32-Debug-a049813d
20260929-140945-x64-Release-639e6068
20260929-141126-Win32-Release-3591a9e6
20260929-141323-ARM64-Release-2e01afa0
```

The Windows build checks and the full dependency archive checks passed under
Windows PowerShell 5.1 and PowerShell 7. Argument rejection, the checkout lock,
Debug output-property consistency, expected BuildUtil Copy failure, and parallel
version-resource generation were checked. The native dependency probes passed
in all four Win32/x64 Release/Debug configurations; the ARM64 probe compiled and
linked, but was not executed on this AMD64 host. These are smoke checks, not the
complete upstream OpenSSL/zlib test suites. No VPN connection, service/driver
installation, or ARM64 runtime test was performed.

vpnweb's MIDL outputs now live in its configuration-specific intermediate
directory. Rebuilding no longer rewrites the tracked generated headers/sources.

## Remaining Work

- Stage the Debug runtime resources and verify Debug applications, not just their
  dependency probes. SeeDll remains a separately loaded Release-only DLL; it is
  not the static-archive source of the resolved Debug CRT link warning.
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
