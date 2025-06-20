; Script generated by the Inno Script Studio Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

#define MyAppName "PlaeyConect"
#define MyAppVersion "1.5"
#define MyAppPublisher "Conect solutions em Servi�os em Ti Ltda"
#define MyAppURL "http://www.conectsolutionsti.dev.br"
#define MyAppExeName "VideoPlayerConect.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{4362F1BF-C142-4CCC-A741-D2299CFBBC3A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={pf}\Conect Palyer
DisableDirPage=yes
DefaultGroupName=Conect Player
OutputDir=C:\FONTES\carregar vumeter em panel\instalador\Output
OutputBaseFilename=setup_ConectPlayer
Password=123456
Compression=lzma
SolidCompression=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "C:\FONTES\carregar vumeter em panel\instalador\VUMeter.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\FONTES\carregar vumeter em panel\Win32\Debug\Unit1.dcu"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\FONTES\carregar vumeter em panel\Win32\Debug\VideoPlayerConect.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\FONTES\carregar vumeter em panel\Win32\Debug\WMPLib_TLB.dcu"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
