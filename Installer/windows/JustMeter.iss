#define Version "0.1.3"
[Setup]
AppId={{91A6CB07-15A4-4697-92C7-41E7BF0D0953}
AppName=Just Meter
AppVersion={#Version}
AppPublisher=Yee Huang
DefaultDirName={autopf}\Just Meter
DefaultGroupName=Just Meter
OutputDir=..\..\outputs
OutputBaseFilename=Just-Meter-{#Version}-Windows-x64-preview-Setup
SetupIconFile=..\..\build\windows\generated\JustMeter.ico
UninstallDisplayIcon={app}\Just Meter.ico
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
PrivilegesRequired=admin
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=yes
LicenseFile=..\..\LICENSE
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "..\..\vendor\ChineseSimplified.isl"

[CustomMessages]
english.Full=Standalone app and VST3 plug-in
english.Custom=Custom installation
english.App=Standalone application
english.Plugin=VST3 plug-in (64-bit)
english.Desktop=Create a desktop shortcut
english.Launch=Open Just Meter
english.Runtime=Microsoft WebView2 Runtime could not be installed. Please retry the installer. Error: 
english.SelectComponent=Select the standalone app, VST3 plug-in, or both.
english.InstallingRuntime=Installing the Microsoft WebView2 Runtime…
chinesesimplified.Full=独立软件和 VST3 插件
chinesesimplified.Custom=自定义安装
chinesesimplified.App=独立软件
chinesesimplified.Plugin=VST3 插件（64 位）
chinesesimplified.Desktop=创建桌面快捷方式
chinesesimplified.Launch=打开 Just Meter
chinesesimplified.Runtime=无法安装 Microsoft WebView2 运行时，请重新运行安装程序。错误：
chinesesimplified.SelectComponent=请选择独立软件、VST3 插件或两者。
chinesesimplified.InstallingRuntime=正在安装 Microsoft WebView2 运行时…

[Types]
Name: "full"; Description: "{cm:Full}"
Name: "custom"; Description: "{cm:Custom}"; Flags: iscustom
[Components]
Name: "app"; Description: "{cm:App}"; Types: full
Name: "vst3"; Description: "{cm:Plugin}"; Types: full
[Tasks]
Name: "desktopicon"; Description: "{cm:Desktop}"; Components: app; Flags: unchecked
[Files]
Source: "..\..\build\windows\Release\Just Meter.exe"; DestDir: "{app}"; Components: app; Flags: ignoreversion
Source: "..\..\build\windows\VST3\Release\JustMeter.vst3\*"; DestDir: "{commoncf64}\VST3\JustMeter.vst3"; Components: vst3; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\build\windows\generated\JustMeter.ico"; DestDir: "{app}"; DestName: "Just Meter.ico"; Flags: ignoreversion
Source: "..\..\build\windows-package\Licenses\*"; DestDir: "{app}\Licenses"; Flags: ignoreversion recursesubdirs
Source: "..\..\vendor\WebView2RuntimeInstallerX64.exe"; Flags: dontcopy
[Icons]
Name: "{group}\Just Meter"; Filename: "{app}\Just Meter.exe"; Components: app
Name: "{autodesktop}\Just Meter"; Filename: "{app}\Just Meter.exe"; Components: app; Tasks: desktopicon
[Run]
Filename: "{app}\Just Meter.exe"; Description: "{cm:Launch}"; Components: app; Flags: nowait postinstall skipifsilent
[Code]
function HasRuntime: Boolean;
var Version: String;
begin
  Result := (RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0')) or
    (RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '') and (Version <> '0.0.0.0'));
end;
function PrepareToInstall(var NeedsRestart: Boolean): String;
var ResultCode: Integer;
begin
  Result := '';
  if not HasRuntime then begin
    ExtractTemporaryFile('WebView2RuntimeInstallerX64.exe');
    WizardForm.StatusLabel.Caption := CustomMessage('InstallingRuntime');
    if not Exec(ExpandConstant('{tmp}\WebView2RuntimeInstallerX64.exe'), '/silent /install', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or not HasRuntime then
      Result := CustomMessage('Runtime') + IntToStr(ResultCode);
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpSelectComponents) and (WizardSelectedComponents(False) = '') then begin
    MsgBox(CustomMessage('SelectComponent'), mbInformation, MB_OK);
    Result := False;
  end;
end;
