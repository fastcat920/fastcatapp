[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={code:LocalizedAppDisplayName}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={sd}\{{INSTALL_DIR_NAME}}
UsePreviousAppDir=yes
DisableDirPage=no
DisableProgramGroupPage=yes
OutputDir={{OUTPUT_DIR}}
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64os or arm64
ArchitecturesInstallIn64BitMode=x64os or arm64
RestartIfNeededByRun=no

[Code]
function IsInAppUpdate: Boolean;
begin
  Result := ExpandConstant('{param:FASTCATUPDATE|0}') = '1';
end;

function GetUserDefaultUILanguage(): Integer;
  external 'GetUserDefaultUILanguage@kernel32.dll stdcall';

function UsesChineseSystemLanguage(): Boolean;
begin
  Result := (GetUserDefaultUILanguage() and $3FF) = $04;
end;

function LocalizedAppDisplayName(Param: String): String;
begin
  if UsesChineseSystemLanguage() then
    Result := '快猫'
  else
    Result := 'FastCat';
end;

function LocalizedLaunchApp(Param: String): String;
begin
  if UsesChineseSystemLanguage() then
    Result := '启动快猫'
  else
    Result := 'Launch FastCat';
end;

procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['{{EXECUTABLE_NAME}}', 'fastcatCore.exe', 'fastcatHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function IsProcessRunning(ProcessName: String): Boolean;
var
  ResultCode: Integer;
begin
  Exec(
    'cmd.exe',
    '/C tasklist /FI "IMAGENAME eq ' + ProcessName + '" | find /I "' + ProcessName + '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
  Result := ResultCode = 0;
end;

function HasRunningProcesses(): Boolean;
var
  Processes: TArrayOfString;
  i: Integer;
begin
  Processes := ['{{EXECUTABLE_NAME}}', 'fastcatCore.exe', 'fastcatHelperService.exe'];
  Result := False;

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    if IsProcessRunning(Processes[i]) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Attempt: Integer;
  ResultCode: Integer;
begin
  Result := '';
  if IsInAppUpdate then
    for Attempt := 1 to 15 do
    begin
      if not IsProcessRunning('{{EXECUTABLE_NAME}}') then Break;
      Sleep(1000);
    end;
  Exec(ExpandConstant('{sys}\sc.exe'), 'stop fastcatHelperService', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  KillProcesses;
end;

function InitializeUninstall(): Boolean;
begin
  Result := True;
  if HasRunningProcesses() then
  begin
    if MsgBox(ExpandConstant('{cm:CloseRunningAppsPrompt}'), mbConfirmation, MB_YESNO) = IDYES then
      KillProcesses
    else
      Result := False;
  end;
end;

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chineseSimplified"; MessagesFile: "{{CHINESE_ISL}}"

[CustomMessages]
english.CloseRunningAppsPrompt=The application is still running. Please close it first. Click Yes to close it automatically and continue uninstalling, or No to cancel.
chineseSimplified.CloseRunningAppsPrompt=应用仍在运行，请先关闭应用。点击“是”将自动关闭应用并继续卸载，点击“否”取消卸载。

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
[Files]
Source: "{{SOURCE_X64}}\*"; DestDir: "{app}"; Excludes: "payload-info.json"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: not IsArm64
Source: "{{SOURCE_ARM64}}\*"; DestDir: "{app}"; Excludes: "payload-info.json"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: IsArm64
Source: "{{RUNTIME_DIR}}\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: not IsArm64
Source: "{{RUNTIME_DIR}}\vc_redist.arm64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: IsArm64
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[InstallDelete]
; Shortcut captions are decided when the installer runs. Remove both previous
; language variants on upgrade so a system-language change cannot leave a
; stale desktop or Start Menu entry behind.
Type: files; Name: "{autoprograms}\\快猫.lnk"
Type: files; Name: "{autoprograms}\\FastCat.lnk"
Type: files; Name: "{autodesktop}\\快猫.lnk"
Type: files; Name: "{autodesktop}\\FastCat.lnk"

[Icons]
Name: "{autoprograms}\\{code:LocalizedAppDisplayName}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; IconFilename: "{app}\\{{EXECUTABLE_NAME}}"; IconIndex: 0
Name: "{autodesktop}\\{code:LocalizedAppDisplayName}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; IconFilename: "{app}\\{{EXECUTABLE_NAME}}"; IconIndex: 0; Tasks: desktopicon
[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ runtime..."; Flags: waituntilterminated; Check: not IsArm64
Filename: "{tmp}\vc_redist.arm64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ runtime..."; Flags: waituntilterminated; Check: IsArm64
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{code:LocalizedLaunchApp}"; Flags: runasoriginaluser nowait postinstall skipifsilent; Check: not IsInAppUpdate
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Flags: nowait runasoriginaluser; Check: IsInAppUpdate
