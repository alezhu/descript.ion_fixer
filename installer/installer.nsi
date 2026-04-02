!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef VERSION
    !define VERSION "1.0.0"
!endif

!define DISPLAY_NAME "Descript.ion Fixer"
Name "${DISPLAY_NAME} Installer"
OutFile "descript.ion_fixer_${VERSION}_installer.exe"
Icon "..\icon.ico"

; Устанавливаем 64-битный режим
InstallDir "$PROGRAMFILES64\${DISPLAY_NAME}"
RequestExecutionLevel admin

InstallDirRegKey HKLM "Software\${DISPLAY_NAME}" "Install_Dir"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section
    SetShellVarContext all

    SetOutPath $INSTDIR
    File /r "..\zig-out\bin\descript.ion_fixer.exe"

    WriteUninstaller $INSTDIR\uninstaller.exe

    ; Write the installation path into the registry
    WriteRegStr HKLM "SOFTWARE\${DISPLAY_NAME}" "Install_Dir" "$INSTDIR"

    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DISPLAY_NAME}" "DisplayName" "${DISPLAY_NAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DISPLAY_NAME}" "UninstallString" '"$INSTDIR\uninstaller.exe"'
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DISPLAY_NAME}" "DisplayIcon" "$INSTDIR\descript.ion_fixer.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DISPLAY_NAME}" "Publisher" "alezhu"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DISPLAY_NAME}" "DisplayVersion" "${VERSION}"


    DetailPrint "${DISPLAY_NAME} Installed"
SectionEnd

Section "Uninstall"
    Delete $INSTDIR\uninstaller.exe
    Delete $INSTDIR\descript.ion_fixer.exe
    RMDir $INSTDIR
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DISPLAY_NAME}"
SectionEnd

