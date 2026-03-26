; ================================================================
; Patriot Ultra Blocker — Uninstaller
; ================================================================

; === AutoIt3Wrapper — File Properties ===
#AutoIt3Wrapper_Icon=patriot.ico
#AutoIt3Wrapper_OutFile=patriot_uninstaller.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Res_FileVersion=1.0.1.0
#AutoIt3Wrapper_Res_ProductVersion=1.0.1.0
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AutoIt3Wrapper_Res_Field=FileDescription|Patriot Ultra Blocker — Uninstaller
#AutoIt3Wrapper_Res_Field=ProductName|Patriot Ultra Blocker
#AutoIt3Wrapper_Res_Field=CompanyName|Think-C
#AutoIt3Wrapper_Res_Field=LegalCopyright|Copyright © 2026 Think-C. All rights reserved.
#AutoIt3Wrapper_Res_Field=OriginalFilename|patriot_uninstaller.exe
#AutoIt3Wrapper_Res_Field=InternalName|PatriotUninstaller
#AutoIt3Wrapper_Res_Field=Assembly|Patriot Ultra Blocker Uninstaller
#AutoIt3Wrapper_Res_Field=Comments|Uninstaller for Patriot Ultra Blocker

#NoTrayIcon
#RequireAdmin

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <Crypt.au3>
#include <WinAPI.au3>

; Identical colors
Global Const $C_BG     = 0x0F172A
Global Const $C_HEADER = 0x0F172A
Global Const $C_CARD   = 0x1E293B
Global Const $C_ACCENT = 0x2563EB
Global Const $C_DANGER = 0xDC2626
Global Const $C_TEXT   = 0xF1F5F9
Global Const $C_SUB    = 0x94A3B8
Global Const $C_BORDER = 0x334155
Global Const $C_GREEN  = 0x22C55E

Global Const $APP_NAME = "Patriot Ultra Blocker"
Global Const $APP_VER  = "1.0.1"

; Read install path from registry
Global $instPath = RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\PatriotUltraBlocker", "InstallLocation")
If $instPath = "" Then $instPath = @ProgramFilesDir & "\Patriot Ultra Blocker"
Global $basePath  = EnvGet("ALLUSERSPROFILE") & "\Patriot"
Global $cfgFile   = $basePath & "\config.ini"
Global $storedHash = IniRead($cfgFile, "security", "password", "")

Global $hWin       = 0
Global $btnMinW    = 0
Global $btnCloseW  = 0
Global $pConfirm   = 0
Global $pProgress  = 0
Global $pDone      = 0

; Step 1 controls
Global $inp_upw      = 0
Global $lbl_uerr     = 0
Global $chk_keep     = 0
Global $btn_uninst   = 0
Global $lbl_uprg     = 0

; Step 2 controls
Global $lbl_uprog_stat = 0
Global $uprog_bar      = 0
Global $lbl_uprog_pct  = 0

; Step 3 controls
Global $btn_udone = 0

_Crypt_Startup()
AutoItWinSetTitle("Patriot Ultra Blocker Uninstaller")
_ShowUninstaller()

; ================================================================
Func _ShowUninstaller()

    $hWin = GUICreate("", 900, 600, -1, -1, $WS_POPUP)
    GUISetBkColor($C_BG)

    ; Header
    Local $hdr = GUICtrlCreateLabel("", 0, 0, 900, 50)
    GUICtrlSetBkColor($hdr, $C_HEADER)
    GUICtrlSetState($hdr, $GUI_DISABLE)

    Local $ico = @ProgramFilesDir & "\Patriot Ultra Blocker\patriot.ico"
    If Not FileExists($ico) Then $ico = @ScriptFullPath
    GUICtrlCreateIcon($ico, -1, 15, 9, 32, 32)

    Local $t = GUICtrlCreateLabel($APP_NAME & " Uninstaller", 60, 14, 400, 22)
    GUICtrlSetColor($t, 0xFFFFFF)
    GUICtrlSetFont($t, 13, 700, 0, "Segoe UI")
    GUICtrlSetBkColor($t, -2)

    Local $v = GUICtrlCreateLabel("v" & $APP_VER & "  ·  Uninstaller", 270, 17, 200, 16)
    GUICtrlSetColor($v, $C_SUB)
    GUICtrlSetFont($v, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($v, -2)

    $btnMinW = GUICtrlCreateLabel("—", 800, 0, 50, 50, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btnMinW, 14, 700, 0, "Segoe UI")
    GUICtrlSetColor($btnMinW, $C_TEXT)
    GUICtrlSetBkColor($btnMinW, $C_HEADER)
    GUICtrlSetCursor($btnMinW, 0)

    $btnCloseW = GUICtrlCreateLabel("✕", 850, 0, 50, 50, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btnCloseW, 13, 700, 0, "Segoe UI")
    GUICtrlSetColor($btnCloseW, $C_TEXT)
    GUICtrlSetBkColor($btnCloseW, $C_HEADER)
    GUICtrlSetCursor($btnCloseW, 0)

    ; Sidebar
    Local $side = GUICtrlCreateLabel("", 0, 50, 180, 550)
    GUICtrlSetBkColor($side, $C_HEADER)
    GUICtrlSetState($side, $GUI_DISABLE)
    GUICtrlCreateLabel("", 180, 50, 1, 550)
    GUICtrlSetBkColor(-1, $C_BORDER)

    _SideLabel("01  Confirm", 90, True)
    _SideLabel("02  Removing", 150, False)
    _SideLabel("03  Complete", 210, False)

    Local $lbI = GUICtrlCreateLabel($APP_NAME & @CRLF & "v" & $APP_VER, 10, 520, 160, 36)
    GUICtrlSetColor($lbI, $C_SUB)
    GUICtrlSetFont($lbI, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbI, -2)

    GUICtrlCreateLabel("", 185, 555, 715, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    ; Panels
    _BuildConfirm()
    _BuildUninstProgress()
    _BuildUninstDone()

    _ShowUPanel($pConfirm)

    GUIRegisterMsg($WM_LBUTTONDOWN, "_DragWin")
    GUISetState(@SW_SHOW, $hWin)

    While 1
        Local $msg = GUIGetMsg()
        If $msg = $GUI_EVENT_CLOSE Or $msg = $btnCloseW Then Exit
        If $msg = $btnMinW Then WinSetState($hWin, "", @SW_MINIMIZE)
        _HandleConfirm($msg)
        _HandleUDone($msg)
    WEnd

EndFunc

Func _SideLabel($text, $y, $active)
    Local $l = GUICtrlCreateLabel($text, 10, $y, 160, 28, $SS_CENTERIMAGE)
    If $active Then
        GUICtrlSetFont($l, 9, 700, 0, "Segoe UI")
        GUICtrlSetColor($l, $C_TEXT)
    Else
        GUICtrlSetFont($l, 9, 400, 0, "Segoe UI")
        GUICtrlSetColor($l, $C_SUB)
    EndIf
    GUICtrlSetBkColor($l, -2)
EndFunc

Func _ShowUPanel($p)
    GUISwitch($hWin)
    If IsHWnd($pConfirm)  Then GUISetState(@SW_HIDE, $pConfirm)
    If IsHWnd($pProgress) Then GUISetState(@SW_HIDE, $pProgress)
    If IsHWnd($pDone)     Then GUISetState(@SW_HIDE, $pDone)
    GUISetState(@SW_SHOW, $p)
    GUISwitch($hWin)
EndFunc

; ================================================================
; STEP 1 — Confirm + Password
; ================================================================
Global $inp_upw, $lbl_uerr, $chk_keep, $btn_uninst, $lbl_uprg

Func _BuildConfirm()

    $pConfirm = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pConfirm)
    GUISetBkColor($C_BG)

    GUICtrlCreateLabel("Uninstall " & $APP_NAME, 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Enter your protection password to confirm.", 30, 52, 500, 20)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("", 30, 78, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    ; Info card
    Local $c1 = GUICtrlCreateLabel("", 30, 92, 620, 120)
    GUICtrlSetBkColor($c1, $C_CARD)

    GUICtrlCreateLabel("The following will be removed:", 60, 106, 560, 18)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 9, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    Local $items[3] = ["Application files: " & $instPath, _
                       "Registry entries (autostart, Add/Remove Programs)", _
                       "Shortcuts (Desktop, Start Menu)"]
    For $i = 0 To 2
        Local $li = GUICtrlCreateLabel("· " & $items[$i], 72, 128 + ($i * 22), 540, 18)
        GUICtrlSetColor($li, $C_SUB)
        GUICtrlSetFont($li, 9, 400, 0, "Segoe UI")
        GUICtrlSetBkColor($li, -2)
    Next

    ; Password card
    Local $c2 = GUICtrlCreateLabel("", 30, 226, 620, 120)
    GUICtrlSetBkColor($c2, $C_CARD)

    GUICtrlCreateLabel("Protection Password", 60, 240, 300, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    $inp_upw = GUICtrlCreateInput("", 60, 262, 560, 34, $ES_PASSWORD)
    GUICtrlSetFont($inp_upw, 11, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($inp_upw, 0x0F172A)
    GUICtrlSetColor($inp_upw, $C_TEXT)

    $lbl_uerr = GUICtrlCreateLabel("", 60, 302, 560, 18)
    GUICtrlSetColor($lbl_uerr, $C_DANGER)
    GUICtrlSetFont($lbl_uerr, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_uerr, -2)

    ; Keep data option
    $chk_keep = GUICtrlCreateCheckbox("Keep protection data (quarantine, logs, backups)", 30, 362, 500, 24)
    GUICtrlSetFont($chk_keep, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($chk_keep, $C_TEXT)
    GUICtrlSetBkColor($chk_keep, -2)
    GUICtrlSetState($chk_keep, $GUI_CHECKED)

    GUICtrlCreateLabel("If unchecked: all Patriot data in C:\ProgramData\Patriot will be deleted", 50, 390, 560, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 8, 400, 2, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    ; Buttons
    $btn_uninst = GUICtrlCreateLabel("Uninstall", 540, 490, 140, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_uninst, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor($btn_uninst, 0xFFFFFF)
    GUICtrlSetBkColor($btn_uninst, $C_DANGER)
    GUICtrlSetCursor($btn_uninst, 0)

    GUICtrlCreateLabel("Cancel", 440, 490, 80, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetBkColor(-1, -2)
    GUICtrlSetCursor(-1, 0)

EndFunc

Func _HandleConfirm($ctrl)
    If $ctrl <> $btn_uninst Then Return
    Local $pw = GUICtrlRead($inp_upw)
    If $pw = "" Then
        GUICtrlSetData($lbl_uerr, "Password is required.")
        Return
    EndIf
    If $storedHash <> "" And Not _VerifyPasswordCompat($pw, $storedHash) Then
        GUICtrlSetData($lbl_uerr, "Incorrect password.")
        Return
    EndIf
    Local $keepData = (GUICtrlRead($chk_keep) = $GUI_CHECKED)
    _ShowUPanel($pProgress)
    _DoUninstall($keepData)
EndFunc

; ================================================================
; STEP 2 — Progress
; ================================================================
Global $lbl_uprog_stat, $uprog_bar, $lbl_uprog_pct

Func _BuildUninstProgress()

    $pProgress = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pProgress)
    GUISetBkColor($C_BG)

    GUICtrlCreateLabel("Removing...", 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Please wait while Patriot is being removed.", 30, 52, 500, 20)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("", 30, 78, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    Local $card = GUICtrlCreateLabel("", 30, 100, 620, 200)
    GUICtrlSetBkColor($card, $C_CARD)

    $lbl_uprog_stat = GUICtrlCreateLabel("Stopping processes...", 60, 130, 560, 22)
    GUICtrlSetColor($lbl_uprog_stat, $C_TEXT)
    GUICtrlSetFont($lbl_uprog_stat, 11, 600, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_uprog_stat, -2)

    GUICtrlCreateLabel("", 60, 164, 560, 16)
    GUICtrlSetBkColor(-1, $C_BORDER)

    $uprog_bar = GUICtrlCreateLabel("", 60, 164, 1, 16)
    GUICtrlSetBkColor($uprog_bar, $C_DANGER)

    $lbl_uprog_pct = GUICtrlCreateLabel("0%", 60, 186, 560, 18)
    GUICtrlSetColor($lbl_uprog_pct, $C_SUB)
    GUICtrlSetFont($lbl_uprog_pct, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_uprog_pct, -2)

EndFunc

Func _SetUProgress($pct, $status)
    GUICtrlSetData($lbl_uprog_stat, $status)
    GUICtrlSetData($lbl_uprog_pct, $pct & "%")
    Local $w = Int(560 * $pct / 100)
    If $w < 1 Then $w = 1
    GUICtrlSetPos($uprog_bar, 60, 164, $w, 16)
    WinSetTitle($hWin, "", "")
    GUISwitch($pProgress)
EndFunc

; ================================================================
; STEP 3 — Done
; ================================================================
Global $btn_udone

Func _BuildUninstDone()

    $pDone = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pDone)
    GUISetBkColor($C_BG)

    GUICtrlCreateLabel("Uninstall Complete", 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel($APP_NAME & " has been removed from this computer.", 30, 52, 600, 20)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("", 30, 78, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    Local $card = GUICtrlCreateLabel("", 30, 100, 620, 160)
    GUICtrlSetBkColor($card, $C_CARD)

    GUICtrlCreateLabel("✓", 60, 118, 50, 50)
    GUICtrlSetColor(-1, $C_GREEN)
    GUICtrlSetFont(-1, 30, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Removed Successfully", 122, 128, 400, 24)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 13, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Thank you for using " & $APP_NAME & ".", 60, 174, 560, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    $btn_udone = GUICtrlCreateLabel("Close", 560, 490, 100, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_udone, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor($btn_udone, 0xFFFFFF)
    GUICtrlSetBkColor($btn_udone, $C_BORDER)
    GUICtrlSetCursor($btn_udone, 0)

EndFunc

Func _HandleUDone($ctrl)
    If $ctrl = $btn_udone Then Exit
EndFunc

; ================================================================
; _DoUninstall
; ================================================================
Func _DoUninstall($keepData)

    _SetUProgress(10, "Stopping processes...")
    ProcessClose("patriot.exe")
    ProcessClose("ultrablocker.exe")
    Sleep(400)
    Run(@ComSpec & " /c taskkill /IM patriot.exe /F >nul 2>&1",      "", @SW_HIDE)
    Run(@ComSpec & " /c taskkill /IM ultrablocker.exe /F >nul 2>&1", "", @SW_HIDE)
    Sleep(600)

    _SetUProgress(25, "Removing registry entries...")
    RegDelete("HKLM\Software\Microsoft\Windows\CurrentVersion\Run",    "PatriotUltraBlocker")
    RegDelete("HKCU\Software\Microsoft\Windows\CurrentVersion\Run",    "PatriotUltraBlocker")
    RegDelete("HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\PatriotUltraBlocker")

    ; Hapus Windows Event Log source registration
    RegDelete("HKLM\\SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application\\PatriotUltraBlocker")

    _SetUProgress(40, "Removing Scheduled Task...")
    RunWait(@ComSpec & ' /c schtasks /Delete /TN "PatriotUltraBlocker" /F >nul 2>&1', "", @SW_HIDE)

    _SetUProgress(55, "Stopping and removing service...")
    RunWait(@ComSpec & ' /c sc stop PatriotProtection >nul 2>&1',   "", @SW_HIDE)
    Sleep(500)
    RunWait(@ComSpec & ' /c sc delete PatriotProtection >nul 2>&1', "", @SW_HIDE)

    ; Hapus semua firewall rules yang dibuat Patriot
    RunWait(@ComSpec & ' /c netsh advfirewall firewall delete rule name="PatriotBlock*" >nul 2>&1', "", @SW_HIDE)
    RunWait(@ComSpec & ' /c netsh advfirewall firewall delete rule name="Patriot*" >nul 2>&1', "", @SW_HIDE)

    _SetUProgress(70, "Removing shortcuts...")
    FileDelete(@DesktopDir         & "\" & $APP_NAME & ".lnk")
    FileDelete(@DesktopCommonDir   & "\" & $APP_NAME & ".lnk")
    FileDelete(@StartupDir         & "\PatriotUltraBlocker.lnk")
    FileDelete(@StartupCommonDir   & "\PatriotUltraBlocker.lnk")
    DirRemove(@StartMenuDir        & "\Programs\Patriot Ultra Blocker", 1)
    DirRemove(@StartMenuCommonDir  & "\Programs\Patriot Ultra Blocker", 1)

    _SetUProgress(82, "Removing data...")
    If Not $keepData Then
        FileSetAttrib($basePath & "\*", "-R", 1)
        ; Hapus honeypot files dari folder user
    Local $honeyDir = @UserProfileDir & "\Documents\PatriotVault"
    If FileExists($honeyDir) Then DirRemove($honeyDir, 1)
    ; Honeypot di lokasi lain
    Local $honeyLocs[5]
    $honeyLocs[0] = @UserProfileDir & "\Documents\Work"
    $honeyLocs[1] = @UserProfileDir & "\Pictures\2024"
    $honeyLocs[2] = @UserProfileDir & "\Desktop\Projects"
    $honeyLocs[3] = @AppDataDir & "\Temp\PatriotDecoy"
    $honeyLocs[4] = @TempDir & "\PatriotDecoy"
    Local $hi
    For $hi = 0 To 4
        If FileExists($honeyLocs[$hi]) Then DirRemove($honeyLocs[$hi], 1)
    Next
    DirRemove($basePath, 1)
    Else
        FileDelete($basePath & "\config.ini")
        FileDelete($basePath & "\install.log")
        DirRemove($basePath & "\logs", 1)
    EndIf

    _SetUProgress(93, "Removing application files...")
    FileSetAttrib($instPath & "\*", "-R", 1)
    ; Self-delete scheduled — installer berjalan dari sini jadi tidak bisa hapus diri sendiri
    Run(@ComSpec & ' /c timeout /t 2 /nobreak >nul & rd /s /q "' & $instPath & '"', "", @SW_HIDE)

    _SetUProgress(100, "Complete!")
    Sleep(400)
    _ShowUPanel($pDone)

EndFunc

; ================================================================
; Shared helpers
; ================================================================
Func _HashString($text)
    _Crypt_Startup()
    Local $bin = _Crypt_HashData($text, $CALG_SHA_256)
    If @error Then Return ""
    Return StringLower(Hex($bin))
EndFunc

; [C-02 FIX] Verifikasi password mendukung format v2 salted (dari install baru) DAN
; format lama plain SHA-256 — backward compatible dengan instalasi lama.
Func _VerifyPasswordCompat($sPassword, $sStoredHash)
    If StringLeft($sStoredHash, 3) = "v2:" Then
        Local $aParts = StringSplit($sStoredHash, ":", 2)
        If UBound($aParts) < 3 Then Return False
        Local $sSalt     = $aParts[1]
        Local $sExpected = $aParts[2]
        _Crypt_Startup()
        Local $sComputed = StringLower(Hex(_Crypt_HashData($sSalt & $sPassword, $CALG_SHA_256)))
        Return ($sComputed = $sExpected)
    Else
        ; Format lama: plain SHA-256
        Return (_HashString($sPassword) = $sStoredHash)
    EndIf
EndFunc

Func _DragWin($hWnd, $Msg, $wParam, $lParam)
    If $Msg = $WM_LBUTTONDOWN Then
        _WinAPI_ReleaseCapture()
        DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $hWin, "uint", 0xA1, "wparam", 2, "lparam", 0)
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc
