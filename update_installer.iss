; Binary name matches BINARY_NAME in windows/CMakeLists.txt
; CI passes /DMyBinaryName=<actual_exe_name> on the command line (step 12d).
; The #ifndef guard ensures the command-line value is NOT overridden by this file.
#ifndef MyBinaryName
#define MyBinaryName "fastcat"
#endif

#ifndef MyAppName
#define MyAppName "fastcat"
#endif
#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif
#ifndef MyAppId
#define MyAppId "9534642D-C46F-4EF0-8B3F-EF152ABEC560"
#endif

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppId={{{#MyAppId}}
DefaultDirName={sd}\{#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename={#MyAppName}-{#MyAppVersion}-windows-amd64-setup
SetupIconFile=windows\runner\resources\app_icon.ico
PrivilegesRequired=admin
CreateUninstallRegKey=yes
Uninstallable=yes
UninstallDisplayName={#MyAppName}

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"; Flags: checkedonce

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "windows\runner\resources\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyBinaryName}.exe"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyBinaryName}.exe"; IconFilename: "{app}\app_icon.ico"; IconIndex: 0; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "正在安装 Visual C++ 运行库..."; Flags: waituntilterminated

[Code]
// 卸载时清除 AppData（登录状态、配置缓存等）
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    // CompanyName=com.follow, ProductName=fastcat → path_provider 存储路径
    DelTree(ExpandConstant('{userappdata}\com.follow\fastcat'), True, True, True);
end;
