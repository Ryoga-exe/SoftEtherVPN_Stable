SETLOCAL
SET BATCH_FILE_NAME=%0
SET BATCH_DIR_NAME=%0\..
SET NOW_TMP=%time:~0,2%
SET NOW=%date:~0,4%%date:~5,2%%date:~8,2%_%NOW_TMP: =0%%time:~3,2%%time:~6,2%

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
echo on

del %BATCH_DIR_NAME%\bin\BuildUtil.exe

"C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" /verbosity:detailed /target:Clean /property:Configuration=Debug "%BATCH_DIR_NAME%\BuildUtil\BuildUtil.csproj"

"C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" /verbosity:detailed /target:Rebuild /property:Configuration=Debug "%BATCH_DIR_NAME%\BuildUtil\BuildUtil.csproj"

cmd /k "%BATCH_DIR_NAME%\bin\BuildUtil.exe /CMD:All"


