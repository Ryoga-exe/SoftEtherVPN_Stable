// SoftEther VPN Source Code - Stable Edition Repository
// Build Utility
// 
// SoftEther VPN Server, Client and Bridge are free software under the Apache License, Version 2.0.
// 
// Copyright (c) Daiyuu Nobori.
// Copyright (c) SoftEther VPN Project, University of Tsukuba, Japan.
// Copyright (c) SoftEther Corporation.
// Copyright (c) all contributors on SoftEther VPN project in GitHub.
// 
// All Rights Reserved.
// 
// http://www.softether.org/
// 
// This stable branch is officially managed by Daiyuu Nobori, the owner of SoftEther VPN Project.
// Pull requests should be sent to the Developer Edition Master Repository on https://github.com/SoftEtherVPN/SoftEtherVPN
// 
// License: The Apache License, Version 2.0
// https://www.apache.org/licenses/LICENSE-2.0
// 
// DISCLAIMER
// ==========
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 
// THIS SOFTWARE IS DEVELOPED IN JAPAN, AND DISTRIBUTED FROM JAPAN, UNDER
// JAPANESE LAWS. YOU MUST AGREE IN ADVANCE TO USE, COPY, MODIFY, MERGE, PUBLISH,
// DISTRIBUTE, SUBLICENSE, AND/OR SELL COPIES OF THIS SOFTWARE, THAT ANY
// JURIDICAL DISPUTES WHICH ARE CONCERNED TO THIS SOFTWARE OR ITS CONTENTS,
// AGAINST US (SOFTETHER PROJECT, SOFTETHER CORPORATION, DAIYUU NOBORI OR OTHER
// SUPPLIERS), OR ANY JURIDICAL DISPUTES AGAINST US WHICH ARE CAUSED BY ANY KIND
// OF USING, COPYING, MODIFYING, MERGING, PUBLISHING, DISTRIBUTING, SUBLICENSING,
// AND/OR SELLING COPIES OF THIS SOFTWARE SHALL BE REGARDED AS BE CONSTRUED AND
// CONTROLLED BY JAPANESE LAWS, AND YOU MUST FURTHER CONSENT TO EXCLUSIVE
// JURISDICTION AND VENUE IN THE COURTS SITTING IN TOKYO, JAPAN. YOU MUST WAIVE
// ALL DEFENSES OF LACK OF PERSONAL JURISDICTION AND FORUM NON CONVENIENS.
// PROCESS MAY BE SERVED ON EITHER PARTY IN THE MANNER AUTHORIZED BY APPLICABLE
// LAW OR COURT RULE.
// 
// USE ONLY IN JAPAN. DO NOT USE THIS SOFTWARE IN ANOTHER COUNTRY UNLESS YOU HAVE
// A CONFIRMATION THAT THIS SOFTWARE DOES NOT VIOLATE ANY CRIMINAL LAWS OR CIVIL
// RIGHTS IN THAT PARTICULAR COUNTRY. USING THIS SOFTWARE IN OTHER COUNTRIES IS
// COMPLETELY AT YOUR OWN RISK. THE SOFTETHER VPN PROJECT HAS DEVELOPED AND
// DISTRIBUTED THIS SOFTWARE TO COMPLY ONLY WITH THE JAPANESE LAWS AND EXISTING
// CIVIL RIGHTS INCLUDING PATENTS WHICH ARE SUBJECTS APPLY IN JAPAN. OTHER
// COUNTRIES' LAWS OR CIVIL RIGHTS ARE NONE OF OUR CONCERNS NOR RESPONSIBILITIES.
// WE HAVE NEVER INVESTIGATED ANY CRIMINAL REGULATIONS, CIVIL LAWS OR
// INTELLECTUAL PROPERTY RIGHTS INCLUDING PATENTS IN ANY OF OTHER 200+ COUNTRIES
// AND TERRITORIES. BY NATURE, THERE ARE 200+ REGIONS IN THE WORLD, WITH
// DIFFERENT LAWS. IT IS IMPOSSIBLE TO VERIFY EVERY COUNTRIES' LAWS, REGULATIONS
// AND CIVIL RIGHTS TO MAKE THE SOFTWARE COMPLY WITH ALL COUNTRIES' LAWS BY THE
// PROJECT. EVEN IF YOU WILL BE SUED BY A PRIVATE ENTITY OR BE DAMAGED BY A
// PUBLIC SERVANT IN YOUR COUNTRY, THE DEVELOPERS OF THIS SOFTWARE WILL NEVER BE
// LIABLE TO RECOVER OR COMPENSATE SUCH DAMAGES, CRIMINAL OR CIVIL
// RESPONSIBILITIES. NOTE THAT THIS LINE IS NOT LICENSE RESTRICTION BUT JUST A
// STATEMENT FOR WARNING AND DISCLAIMER.
// 
// READ AND UNDERSTAND THE 'WARNING.TXT' FILE BEFORE USING THIS SOFTWARE.
// SOME SOFTWARE PROGRAMS FROM THIRD PARTIES ARE INCLUDED ON THIS SOFTWARE WITH
// LICENSE CONDITIONS WHICH ARE DESCRIBED ON THE 'THIRD_PARTY.TXT' FILE.
// 
// 
// SOURCE CODE CONTRIBUTION
// ------------------------
// 
// Your contribution to SoftEther VPN Project is much appreciated.
// Please send patches to us through GitHub.
// Read the SoftEther VPN Patch Acceptance Policy in advance:
// http://www.softether.org/5-download/src/9.patch
// 
// 
// DEAR SECURITY EXPERTS
// ---------------------
// 
// If you find a bug or a security vulnerability please kindly inform us
// about the problem immediately so that we can fix the security problem
// to protect a lot of users around the world as soon as possible.
// 
// Our e-mail address for security reports is:
// softether-vpn-security [at] softether.org
// 
// Please note that the above e-mail address is not a technical support
// inquiry address. If you need technical assistance, please visit
// http://www.softether.org/ and ask your question on the users forum.
// 
// Thank you for your cooperation.
// 
// 
// NO MEMORY OR RESOURCE LEAKS
// ---------------------------
// 
// The memory-leaks and resource-leaks verification under the stress
// test has been passed before release this source code.


using System;
using System.Threading;
using System.Text;
using System.Configuration;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Security.Cryptography;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Diagnostics;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using Microsoft.Win32;
using CoreUtil;

namespace BuildUtil
{
	// Languages
	public class Language
	{
		public int Number;
		public string Id;
		public string Title;
		public string TitleUnicode;
		public string WindowsLocaleIds;
		public string UnixLocaleIds;
	}

	// Build helper class
	public static class BuildHelper
	{
		// loads the language list text file
		public static Language[] GetLanguageList()
		{
			return GetLanguageList(Path.Combine(Paths.BinDirName, @"hamcore\languages.txt"));
		}
		public static Language[] GetLanguageList(string filename)
		{
			List<Language> ret = new List<Language>();
			string[] lines = File.ReadAllLines(filename, Str.Utf8Encoding);

			foreach (string line in lines)
			{
				string s = line.Trim();

				if (Str.IsEmptyStr(s) == false)
				{
					if (s.StartsWith("#", StringComparison.InvariantCultureIgnoreCase) == false)
					{
						string[] sps = { " ", "\t", };
						string[] tokens = s.Split(sps, StringSplitOptions.RemoveEmptyEntries);

						if (tokens.Length == 6)
						{
							Language e = new Language();

							e.Number = Str.StrToInt(tokens[0]);
							e.Id = tokens[1];
							e.Title = Str.ReplaceStr(tokens[2], "_", " ");
							e.TitleUnicode = tokens[3];
							e.WindowsLocaleIds = tokens[4];
							e.UnixLocaleIds = tokens[5];

							ret.Add(e);

							Con.WriteLine(tokens.Length);
						}
					}
				}
			}

			return ret.ToArray();
		}

		// Build
		public static void BuildMain(BuildSoftware soft, bool debugModeIfUnix)
		{
			int version, build;
			string name;
			DateTime date;

			string title = Console.Title;
			Console.Title = string.Format("Building {0}", soft.IDString);

			try
			{
				Win32BuildUtil.ReadBuildInfoFromTextFile(out build, out version, out name, out date);

				soft.SetBuildNumberVersionName(build, version, name, date);

				Con.WriteLine("Building '{0}' - {1}...", soft.IDString, soft.TitleString);

				BuildSoftwareUnix softUnix = soft as BuildSoftwareUnix;

				if (softUnix == null)
				{
					soft.Build();
				}
				else
				{
					softUnix.Build(debugModeIfUnix);
				}
			}
			finally
			{
				Console.Title = title;
			}
		}

		// Convert the number to a version number
		public static string VersionIntToString(int version)
		{
			return string.Format("{0}.{1:D2}", version / 100, version % 100);
		}

		// Get a product list that is included in the software
		public static string GetSoftwareProductList(Software soft)
		{
			string ret = "";

			switch (soft)
			{
				case Software.vpnbridge:
					ret = "PacketiX VPN Bridge";
					break;

				case Software.vpnclient:
					ret = "PacketiX VPN Client, PacketiX VPN Command-Line Admin Utility (vpncmd)";
					break;

				case Software.vpnserver:
					ret = "PacketiX VPN Server, PacketiX VPN Command-Line Admin Utility (vpncmd)";
					break;

				case Software.vpnserver_vpnbridge:
					ret = "PacketiX VPN Server, PacketiX VPN Bridge, PacketiX VPN Server Manager for Windows, PacketiX VPN Command-Line Admin Utility (vpncmd)";
					break;

				default:
					throw new ApplicationException("invalid soft.");
			}

#if BU_SOFTETHER
			ret = Str.ReplaceStr(ret, "PacketiX", "SoftEther", false);
#endif

			return ret;
		}

		// Get the title of the software
		public static string GetSoftwareTitle(Software soft)
		{
			string ret = "";

			switch (soft)
			{
				case Software.vpnbridge:
					ret = "PacketiX VPN Bridge";
					break;

				case Software.vpnclient:
					ret = "PacketiX VPN Client";
					break;

				case Software.vpnserver:
					ret = "PacketiX VPN Server";
					break;

				case Software.vpnserver_vpnbridge:
					ret = "PacketiX VPN Server and VPN Bridge";
					break;

				default:
					throw new ApplicationException("invalid soft.");
			}
			
#if BU_SOFTETHER
			ret = Str.ReplaceStr(ret, "PacketiX", "SoftEther", false);
#endif

			return ret;
		}
	}

	// Basic path information
	public static class Paths
	{
		public static readonly string ExeFileName = Env.ExeFileName;
		public static readonly string ExeDirName = Env.ExeFileDir;
		public static readonly string BinDirName = ExeDirName;
		public static readonly string BaseDirName = IO.NormalizePath(Path.Combine(BinDirName, @"..\"));
		public static readonly string UtilityDirName = IO.NormalizePath(Path.Combine(BinDirName, @"..\BuildFiles\Utility"));

#if !BU_SOFTETHER
		// PacketiX VPN (build by SoftEther)
		public static readonly string VPN4SolutionFileName = Path.Combine(BaseDirName, "VPN4.sln");
		public static readonly string DebugSnapshotBaseDir = @"S:\SE4\DebugFilesSnapshot";
		public static readonly string ReleaseDestDir = @"s:\SE4\Releases";
		public const string Prefix = "";
#else
#if !BU_OSS
		// SoftEther VPN (build by SoftEther)
		public static readonly string VPN4SolutionFileName = Path.Combine(BaseDirName, "SEVPN.sln");
		public static readonly string DebugSnapshotBaseDir = @"S:\SE4\DebugFilesSnapshot_SEVPN";
		public static readonly string ReleaseDestDir = @"s:\SE4\Releases_SEVPN";
		public const string Prefix = "softether-";
#else
		// SoftEther VPN (build by Open Source Developers)
		public static readonly string VPN4SolutionFileName = Path.Combine(BaseDirName, "SEVPN.sln");
		public static readonly string DebugSnapshotBaseDir = IO.NormalizePath(Path.Combine(BaseDirName, @"..\output\debug"));
		public static readonly string ReleaseDestDir = IO.NormalizePath(Path.Combine(BaseDirName, @"..\output\pkg"));
		public const string Prefix = "softether_open-";
#endif
#endif

		public static readonly string ReleaseDestDir_SEVPN = @"s:\SE4\Releases_SEVPN";

		public static readonly string BuildHamcoreFilesDirName = Path.Combine(BinDirName, "BuiltHamcoreFiles");
		public static readonly string VisualStudioVCDir;
		public static readonly string VisualStudioVCBatchFileName;
		public static readonly string DotNetFramework35Dir;
		public static readonly string MSBuildFileName;
		public static readonly string TmpDirName;
		public static readonly DateTime StartDateTime = DateTime.Now;
		public static readonly string StartDateTimeStr;
		public static readonly string CmdFileName;
		public static readonly string ManifestsDir = Path.Combine(BaseDirName, @"BuildFiles\Manifests");
		public static readonly string XCopyExeFileName = Path.Combine(Env.SystemDir, "xcopy.exe");
		public static readonly string ReleaseDir = Path.Combine(BaseDirName, @"tmp\Release");
		public static readonly string ReleaseSrckitDir = Path.Combine(BaseDirName, @"tmp\ReleaseSrcKit");
		public static readonly string StringsDir = Path.Combine(BaseDirName, @"BuildFiles\Strings");
		public static readonly string CrossCompilerBaseDir = @"S:\CommomDev\xc";
		public static readonly string UnixInstallScript = Path.Combine(BaseDirName, @"BuildFiles\UnixFiles\InstallScript.txt");
		public static readonly string OssCommentsFile = Path.Combine(StringsDir, "OssComments.txt");
		public static readonly string AutorunSrcDir = IO.NormalizePath(Path.Combine(BaseDirName, @"..\Autorun"));
		public static readonly string MicrosoftSDKDir;
		public static readonly string MakeCatFilename;
		public static readonly string RcFilename;
		public static readonly string SoftEtherBuildDir = Env.SystemDir.Substring(0, 2) + @"\tmp\softether_build_dir";
		public static readonly string OpenSourceDestDir = Env.SystemDir.Substring(0, 2) + @"\tmp\softether_oss_dest_dir";

		private static string NormalizeDirName(string dirName)
		{
			if (Str.IsEmptyStr(dirName))
			{
				return "";
			}

			return IO.RemoteLastEnMark(IO.NormalizePath(dirName));
		}

		private static string GetFirstExistingDirectory(IEnumerable<string> candidates)
		{
			foreach (string candidate in candidates)
			{
				string normalized = NormalizeDirName(candidate);

				if (Str.IsEmptyStr(normalized) == false && Directory.Exists(normalized))
				{
					return normalized;
				}
			}

			return "";
		}

		private static string GetFirstExistingFile(IEnumerable<string> candidates)
		{
			foreach (string candidate in candidates)
			{
				if (Str.IsEmptyStr(candidate))
				{
					continue;
				}

				string normalized = IO.NormalizePath(candidate);
				if (File.Exists(normalized))
				{
					return normalized;
				}
			}

			return "";
		}

		private static void AddVisualStudioVcCandidates(List<string> candidates, string baseDir)
		{
			if (Directory.Exists(baseDir) == false)
			{
				return;
			}

			string[] preferredVersions = { "2022", "17", "18", "2019", "16", "2017", "15", };
			foreach (string version in preferredVersions)
			{
				string versionDir = Path.Combine(baseDir, version);
				if (Directory.Exists(versionDir))
				{
					AddVisualStudioVcCandidatesForVersion(candidates, versionDir);
				}
			}

			foreach (string versionDir in Directory.GetDirectories(baseDir))
			{
				AddVisualStudioVcCandidatesForVersion(candidates, versionDir);
			}
		}

		private static void AddVisualStudioVcCandidatesForVersion(List<string> candidates, string versionDir)
		{
			foreach (string editionDir in Directory.GetDirectories(versionDir))
			{
				string vcDir = Path.Combine(editionDir, "VC");
				if (Directory.Exists(vcDir))
				{
					candidates.Add(vcDir);
				}
			}
		}

		private static string FindVisualStudioVCDir()
		{
			List<string> candidates = new List<string>();
			string envVcToolsDir = Environment.GetEnvironmentVariable("VCToolsInstallDir");
			string envVsInstallDir = Environment.GetEnvironmentVariable("VSINSTALLDIR");
			string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
			string programFilesX86 = Environment.GetEnvironmentVariable("ProgramFiles(x86)");

			if (Str.IsEmptyStr(programFilesX86))
			{
				programFilesX86 = programFiles;
			}

			if (Str.IsEmptyStr(envVcToolsDir) == false)
			{
				candidates.Add(Path.Combine(envVcToolsDir, @"..\.."));
			}
			if (Str.IsEmptyStr(envVsInstallDir) == false)
			{
				candidates.Add(Path.Combine(envVsInstallDir, "VC"));
			}

			candidates.Add(IO.RemoteLastEnMark(Reg.ReadStr(RegRoot.LocalMachine, @"SOFTWARE\Microsoft\VisualStudio\9.0\Setup\VC", "ProductDir")));
			candidates.Add(IO.RemoteLastEnMark(Reg.ReadStr(RegRoot.LocalMachine, @"SOFTWARE\Wow6432Node\Microsoft\VisualStudio\9.0\Setup\VC", "ProductDir")));

			AddVisualStudioVcCandidates(candidates, Path.Combine(programFiles, "Microsoft Visual Studio"));
			AddVisualStudioVcCandidates(candidates, Path.Combine(programFilesX86, "Microsoft Visual Studio"));

			return GetFirstExistingDirectory(candidates);
		}

		private static string FindVisualStudioVCBatchFileName(string vcDir)
		{
			return GetFirstExistingFile(new string[]
			{
				Path.Combine(vcDir, @"Auxiliary\Build\vcvarsall.bat"),
				Path.Combine(vcDir, "vcvarsall.bat"),
			});
		}

		private static string ReadRegistryStringValue(RegistryKey rootKey, string subKey, string valueName)
		{
			try
			{
				using (RegistryKey key = rootKey.OpenSubKey(subKey))
				{
					if (key == null)
					{
						return "";
					}

					object value = key.GetValue(valueName);
					if (value == null)
					{
						return "";
					}

					return value.ToString();
				}
			}
			catch
			{
				return "";
			}
		}

		private static string FindMicrosoftSdkDir()
		{
			List<string> candidates = new List<string>();
			string envWindowsSdkDir = Environment.GetEnvironmentVariable("WindowsSdkDir");

			if (Str.IsEmptyStr(envWindowsSdkDir) == false)
			{
				candidates.Add(envWindowsSdkDir);
			}

			candidates.Add(ReadRegistryStringValue(Registry.LocalMachine, @"SOFTWARE\Microsoft\Windows Kits\Installed Roots", "KitsRoot10"));
			candidates.Add(ReadRegistryStringValue(Registry.LocalMachine, @"SOFTWARE\Wow6432Node\Microsoft\Windows Kits\Installed Roots", "KitsRoot10"));
			candidates.Add(IO.RemoteLastEnMark(Reg.ReadStr(RegRoot.LocalMachine, @"SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v6.0A", "InstallationFolder")));
			candidates.Add(IO.RemoteLastEnMark(Reg.ReadStr(RegRoot.LocalMachine, @"SOFTWARE\Microsoft\Microsoft SDKs\Windows\v6.0A", "InstallationFolder")));

			return GetFirstExistingDirectory(candidates);
		}

		private static string NormalizeSdkVersion(string sdkVersion)
		{
			if (Str.IsEmptyStr(sdkVersion))
			{
				return "";
			}

			return sdkVersion.Trim().Trim('\\', '/');
		}

		private static string FindWindowsSdkBinary(string sdkDir, string toolName, bool x86Dir)
		{
			List<string> candidates = new List<string>();
			string sdkVersion = NormalizeSdkVersion(Environment.GetEnvironmentVariable("WindowsSDKVersion"));
			string arch = x86Dir ? "x86" : "x64";
			string binDir = Path.Combine(sdkDir, "bin");

			if (Str.IsEmptyStr(sdkVersion) == false)
			{
				candidates.Add(Path.Combine(Path.Combine(Path.Combine(binDir, sdkVersion), arch), toolName));
				candidates.Add(Path.Combine(Path.Combine(binDir, sdkVersion), toolName));
			}

			if (Directory.Exists(binDir))
			{
				foreach (string versionDir in Directory.GetDirectories(binDir))
				{
					candidates.Add(Path.Combine(Path.Combine(versionDir, arch), toolName));
					candidates.Add(Path.Combine(versionDir, toolName));
				}
			}

			candidates.Add(Path.Combine(Path.Combine(binDir, arch), toolName));
			candidates.Add(Path.Combine(binDir, toolName));

			return GetFirstExistingFile(candidates);
		}

		// Initialize
		static Paths()
		{
			// Starting date and time string
			Paths.StartDateTimeStr = Str.DateTimeToStrShort(Paths.StartDateTime);

			// Check whether the execution path is the bin directory in the VPN directory
			if (Paths.BinDirName.EndsWith(@"\bin", StringComparison.InvariantCultureIgnoreCase) == false)
			{
				throw new ApplicationException(string.Format("'{0}' is not a VPN bin directory.", Paths.BinDirName));
			}
			if (File.Exists(Paths.VPN4SolutionFileName) == false)
			{
				throw new ApplicationException(string.Format("'{0}' is not a VPN base directory.", Paths.BaseDirName));
			}

			// Get the VC++ directory
			Paths.VisualStudioVCDir = FindVisualStudioVCDir();
			if (Str.IsEmptyStr(Paths.VisualStudioVCDir))
			{
				throw new ApplicationException("Visual C++ directory not found.\n");
			}
			if (Directory.Exists(Paths.VisualStudioVCDir) == false)
			{
				throw new ApplicationException(string.Format("Directory '{0}' not found.", Paths.VisualStudioVCDir));
			}

			// Get the VC++ batch file name
			Paths.VisualStudioVCBatchFileName = FindVisualStudioVCBatchFileName(Paths.VisualStudioVCDir);
			if (Str.IsEmptyStr(Paths.VisualStudioVCBatchFileName))
			{
				throw new ApplicationException(string.Format("File '{0}' not found.", Path.Combine(Paths.VisualStudioVCDir, @"Auxiliary\Build\vcvarsall.bat")));
			}

			bool x86_dir = false;

			// Get Microsoft SDK directory
			Paths.MicrosoftSDKDir = FindMicrosoftSdkDir();
			if (Str.IsEmptyStr(Paths.MicrosoftSDKDir))
			{
				throw new ApplicationException("Microsoft SDK directory not found.\n");
			}

			// Get makecat.exe file name
			Paths.MakeCatFilename = FindWindowsSdkBinary(Paths.MicrosoftSDKDir, "makecat.exe", x86_dir);
			if (Str.IsEmptyStr(Paths.MakeCatFilename))
			{
				throw new ApplicationException("makecat.exe not found.\n");
			}

			// Get the rc.exe file name
			Paths.RcFilename = FindWindowsSdkBinary(Paths.MicrosoftSDKDir, "rc.exe", x86_dir);
			if (Str.IsEmptyStr(Paths.RcFilename))
			{
				throw new ApplicationException("rc.exe not found.\n");
			}

			// Get the cmd.exe file name
			Paths.CmdFileName = Path.Combine(Env.SystemDir, "cmd.exe");
			if (File.Exists(Paths.CmdFileName) == false)
			{
				throw new ApplicationException(string.Format("File '{0}' not found.", Paths.CmdFileName));
			}

			// Get .NET Framework 3.5 directory
			Paths.DotNetFramework35Dir = Path.Combine(Env.WindowsDir, @"Microsoft.NET\Framework\v3.5");

			// Get msbuild.exe directory
			Paths.MSBuildFileName = Path.Combine(Paths.DotNetFramework35Dir, "MSBuild.exe");
			if (File.Exists(Paths.MSBuildFileName) == false)
			{
				throw new ApplicationException(string.Format("File '{0}' not found.", Paths.MSBuildFileName));
			}

			// Get the TMP directory
			Paths.TmpDirName = Path.Combine(Paths.BaseDirName, "tmp");
			if (Directory.Exists(Paths.TmpDirName) == false)
			{
				Directory.CreateDirectory(Paths.TmpDirName);
			}
		}

		public static void DeleteAllReleaseTarGz()
		{
			if (Directory.Exists(Paths.ReleaseDir))
			{
				string[] files = Directory.GetFiles(Paths.ReleaseDir, "*.gz", SearchOption.AllDirectories);

				foreach (string file in files)
				{
					File.Delete(file);
				}
			}

			if (Directory.Exists(Paths.ReleaseSrckitDir))
			{
				string[] files = Directory.GetFiles(Paths.ReleaseSrckitDir, "*.gz", SearchOption.AllDirectories);

				foreach (string file in files)
				{
					File.Delete(file);
				}
			}
		}

		public static void DeleteAllReleaseAdminKits()
		{
			if (Directory.Exists(Paths.ReleaseDir))
			{
				string[] files = Directory.GetFiles(Paths.ReleaseDir, "*.zip", SearchOption.AllDirectories);

				foreach (string file in files)
				{
					if (Str.InStr(file, "vpnadminpak"))
					{
						File.Delete(file);
					}
				}
			}
		}

		public static void DeleteAllReleaseManuals()
		{
			if (Directory.Exists(Paths.ReleaseDir))
			{
				string[] files = Directory.GetFiles(Paths.ReleaseDir, "*", SearchOption.AllDirectories);

				foreach (string file in files)
				{
					if (Str.InStr(file, "vpnmanual"))
					{
						File.Delete(file);
					}
				}
			}
		}

		public static void DeleteAllReleaseExe()
		{
			if (Directory.Exists(Paths.ReleaseDir))
			{
				string[] files = Directory.GetFiles(Paths.ReleaseDir, "*.exe", SearchOption.AllDirectories);

				foreach (string file in files)
				{
					if (Str.InStr(file, "vpnmanual") == false)
					{
						File.Delete(file);
					}
				}
			}
		}
	}

	// HamCore build utility
	public static class HamCoreBuildUtil
	{
		// Identify whether a file is necessary only in the Win32
		public static bool IsFileForOnlyWin32(string filename)
		{
			string[] filesOnlyWin32 =
			{
				".exe",
				".dll",
				".sys",
				".inf",
				".wav",
				".cat",
			};

			foreach (string ext in filesOnlyWin32)
			{
				if (filename.EndsWith(ext, StringComparison.InvariantCultureIgnoreCase))
				{
					return true;
				}
			}

			return false;
		}

		// Delete svn file
		public static void DeleteSVNFilesFromHamCoreBuilder(HamCoreBuilder b)
		{
			List<string> removeFiles = new List<string>();
			foreach (HamCoreBuilderFileEntry f in b.FileList)
			{
				string name = f.Name;
				if (name.StartsWith(".svn", StringComparison.InvariantCultureIgnoreCase) ||
					name.IndexOf(@"\.svn", StringComparison.InvariantCultureIgnoreCase) != -1)
				{
					removeFiles.Add(name);
				}
			}
			foreach (string file in removeFiles)
			{
				b.DeleteFile(file);
			}
		}

		// Delete node_modules file
		public static void DeleteNodeModulesFilesFromHamCoreBuilder(HamCoreBuilder b)
		{
			List<string> removeFiles = new List<string>();
			foreach (HamCoreBuilderFileEntry f in b.FileList)
			{
				string name = f.Name;
				if (name.IndexOf(@"\node_modules\", StringComparison.InvariantCultureIgnoreCase) != -1)
				{
					removeFiles.Add(name);
				}
			}
			foreach (string file in removeFiles)
			{
				b.DeleteFile(file);
			}
		}

		// Build Hamcore file
		public static void BuildHamcore()
		{
			string srcDirNameBasic = Path.Combine(Paths.BinDirName, "hamcore");
			// Create the destination directory
			string win32DestDir = Path.Combine(Paths.BuildHamcoreFilesDirName, "hamcore_win32");
			string win32DestFileName = Path.Combine(win32DestDir, "hamcore.se2");
			string unixDestDir = Path.Combine(Paths.BuildHamcoreFilesDirName, "hamcore_unix");
			string unixDestFileName = Path.Combine(unixDestDir, "hamcore.se2");
			IO.MakeDir(win32DestDir);
			IO.MakeDir(unixDestDir);


			BuildHamcoreEx(srcDirNameBasic, win32DestFileName, unixDestFileName);

			// Copy to bin\hamcore.se2
			try
			{
				string binHamcoreFileName = Path.Combine(Paths.BinDirName, "hamcore.se2");

				try
				{
					File.Delete(binHamcoreFileName);
				}
				catch
				{
				}

				File.Copy(win32DestFileName, binHamcoreFileName, true);
			}
			catch
			{
			}
		}

		public static void BuildHamcoreEx(string srcDirNameBasic, string win32DestFileName, string unixDestFileName)
		{
			HamCoreBuilder b = new HamCoreBuilder();
			b.AddDir(srcDirNameBasic);
			Con.WriteLine("* Building hamcore ...");

			DeleteSVNFilesFromHamCoreBuilder(b);
			DeleteNodeModulesFilesFromHamCoreBuilder(b);

			try
			{
				File.Delete(win32DestFileName);
			}
			catch
			{
			}
			b.Build(win32DestFileName);

			// unix
			List<string> removeFiles = new List<string>();
			foreach (HamCoreBuilderFileEntry f in b.FileList)
			{
				if (IsFileForOnlyWin32(f.Name))
				{
					removeFiles.Add(f.Name);
				}
			}
			foreach (string removeFile in removeFiles)
			{
				b.DeleteFile(removeFile);
			}

			DeleteSVNFilesFromHamCoreBuilder(b);
			DeleteNodeModulesFilesFromHamCoreBuilder(b);

			try
			{
				File.Delete(unixDestFileName);
			}
			catch
			{
			}
			b.Build(unixDestFileName);
		}
	}

	// Number of bits
	public enum CPUBits
	{
		Both,
		Bits32,
		Bits64,
	}

	// Conversion a string to the number of bits
	public static class CPUBitsUtil
	{
		public static CPUBits StringToCPUBits(string str)
		{
			if (str.Equals("32bit", StringComparison.InvariantCultureIgnoreCase))
			{
				return CPUBits.Bits32;
			}
			else if (str.Equals("64bit", StringComparison.InvariantCultureIgnoreCase))
			{
				return CPUBits.Bits64;
			}
			else if (str.Equals("intel", StringComparison.InvariantCultureIgnoreCase))
			{
				return CPUBits.Both;
			}

			throw new ApplicationException(string.Format("Invalid bits string '{0}'.", str));
		}

		public static string CPUBitsToString(CPUBits bits)
		{
			switch (bits)
			{
				case CPUBits.Bits32:
					return "32bit";

				case CPUBits.Bits64:
					return "64bit";

				case CPUBits.Both:
					return "intel";
			}

			throw new ApplicationException("bits invalid.");
		}
	}
}


