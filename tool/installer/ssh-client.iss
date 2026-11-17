; Inno Setup script for the Windows build of SSH Client.
;
; Build the release first (the script aborts if the exe is missing):
;   flutter build windows --release
; Then:
;   "C:\Program Files\Inno Setup 7\ISCC.exe" tool\installer\ssh-client.iss

#define AppName "SSH Client"
#define AppExeName "ssh_client.exe"
#define AppPublisher "dev.sshclient"
#define AppId "{{79B09999-D946-42E3-AB86-A7DF44FD4280}"
#define ReleaseDir "..\..\build\windows\x64\runner\Release"
#define AppExePath AddBackslash(SourcePath) + ReleaseDir + "\" + AppExeName

; The version comes from the VERSIONINFO resource that Flutter writes from
; pubspec.yaml, so there is a single source of truth: 0.1.0+1 becomes 0.1.0.1,
; which keeps the build number in the installer file name.
#if !FileExists(AppExePath)
  #error Release build not found. Run "flutter build windows --release" first.
#endif
#define AppVersion GetVersionNumbersString(AppExePath)

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user install: no UAC prompt, and the profile data of the app is per user
; anyway (%LOCALAPPDATA% and %APPDATA%).
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\installer
OutputBaseFilename=ssh-client-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName} {#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The installer closes a running copy through the Restart Manager instead of
; failing on locked files, and does not reopen it behind the user's back.
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Setup
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "freshdata"; Description: "Empezar de cero: borrar perfiles, servidores y credenciales guardadas de este usuario"; GroupDescription: "Datos existentes"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Removes the two folders that hold this app's data, and only those:
//   %LOCALAPPDATA%\dev.sshclient\ssh_client   catalog, profiles, backups
//   %APPDATA%\dev.sshclient\ssh_client        DPAPI key file, preferences
// It runs before the files are copied, so an aborted install deletes nothing.
procedure DeleteAppData();
var
  Local: String;
  Roaming: String;
begin
  Local := ExpandConstant('{localappdata}\dev.sshclient\ssh_client');
  Roaming := ExpandConstant('{userappdata}\dev.sshclient\ssh_client');

  if DirExists(Local) then
  begin
    Log('Deleting ' + Local);
    if not DelTree(Local, True, True, True) then
      MsgBox('No se pudo borrar ' + Local + '. Cierra la aplicación e inténtalo de nuevo.', mbError, MB_OK);
  end;
  if DirExists(Roaming) then
  begin
    Log('Deleting ' + Roaming);
    if not DelTree(Roaming, True, True, True) then
      MsgBox('No se pudo borrar ' + Roaming + '. Cierra la aplicación e inténtalo de nuevo.', mbError, MB_OK);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssInstall) and WizardIsTaskSelected('freshdata') then
    DeleteAppData();
end;

