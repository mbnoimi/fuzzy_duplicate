; Inno Setup script for Fuzzy Duplicate
; Compile with: ISCC "fuzzy_duplicate.iss"

#define MyAppName "Fuzzy Duplicate"
#define MyAppVersion "0.8.5"
#define MyAppPublisher "mbnoimi"
#define MyAppURL "https://github.com/mbnoimi/fuzzy_duplicate"
#define MyAppExeName "fuzzy_duplicate.exe"

[Setup]
AppId=A4D4E7F0-4B8C-4D9A-9E5A-5F8B0A9E7F0A
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=LICENSE
InfoBeforeFile=README.md
OutputBaseFilename=Fuzzy_Duplicate-{#MyAppVersion}-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Wizard images commented out due to file not found errors
; WizardImageFile=compiler:WizModernImage.bmp
; WizardSmallImageFile=compiler:WizModernSmallImage.bmp

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Welcome to the [name] Setup Wizard
WelcomeLabel2=This will install [name] version [version] on your computer.%n%nIt is recommended that you close all other applications before continuing.

[Types]
Name: "full"; Description: "Full installation"
Name: "compact"; Description: "Compact installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "main"; Description: "Main application files"; Types: full compact custom; Flags: fixed
Name: "desktopicon"; Description: "Desktop icon"; Types: full compact custom

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: postinstall nowait unchecked

[InstallDelete]
Type: filesandordirs; Name: "{app}\*"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\*"

[Registry]
Root: HKCU; Subkey: "Software\{#MyAppName}"; Flags: uninsdeletekeyifempty