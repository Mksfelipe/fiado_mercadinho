; Script Inno Setup para o app "Fiados Mercadinho".
; Compile com: ISCC.exe installer\fiado_mercadinho.iss
; (gere antes o build: flutter build windows --release)

#define MyAppName "Fiados Mercadinho"
; A versão pode ser injetada pela linha de comando: ISCC /DMyAppVersion=1.3.0
; (é o que o GitHub Actions e o build_release.ps1 fazem). Sem isso, usa o padrão.
#ifndef MyAppVersion
  #define MyAppVersion "1.2.0"
#endif
#define MyAppPublisher "Mercadinho"
#define MyAppExeName "fiado_mercadinho.exe"

[Setup]
; AppId identifica o app de forma única (não mude entre versões).
AppId={{8F3A1C7E-2B4D-4E6A-9C1F-7D5E0A2B3C4D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=FiadosMercadinho-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Fecha o app automaticamente se ele estiver aberto durante a atualização
; (necessário para o auto-update funcionar) e o reabre ao terminar.
CloseApplications=yes
RestartApplications=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Copia toda a pasta Release (exe + DLLs + data) recursivamente.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
