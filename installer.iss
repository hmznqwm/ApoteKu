[Setup]
AppName=ApoteKu POS
AppVersion=1.0.0
AppPublisher=Apotek Tia Farma
DefaultDirName={autopf}\ApoteKu
DefaultGroupName=ApoteKu
OutputDir=C:\Users\hmznq\Downloads
OutputBaseFilename=ApoteKu_Windows_Setup_v1.0.0
SetupIconFile=c:\laragon\www\apotek\mobile\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=lowest
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "c:\laragon\www\apotek\mobile\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ApoteKu POS"; Filename: "{app}\apotek_app.exe"
Name: "{group}\{cm:UninstallProgram,ApoteKu POS}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\ApoteKu POS"; Filename: "{app}\apotek_app.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\apotek_app.exe"; Description: "{cm:LaunchProgram,ApoteKu POS}"; Flags: nowait postinstall skipifsilent
