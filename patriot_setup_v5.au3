; === AutoIt3Wrapper — File Properties ===
#AutoIt3Wrapper_Icon=patriot.ico
#AutoIt3Wrapper_OutFile=patriot_setup.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Run_Au3Check=y
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=n
#AutoIt3Wrapper_Res_FileVersion=1.0.1.0
#AutoIt3Wrapper_Res_FileVersion_AutoIncrement=n
#AutoIt3Wrapper_Res_ProductVersion=1.0.1.0
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AutoIt3Wrapper_Res_Field=FileDescription|Patriot Ultra Blocker — Installer
#AutoIt3Wrapper_Res_Field=ProductName|Patriot Ultra Blocker
#AutoIt3Wrapper_Res_Field=CompanyName|Think-C
#AutoIt3Wrapper_Res_Field=LegalCopyright|Copyright © 2026 Think-C. All rights reserved.
#AutoIt3Wrapper_Res_Field=OriginalFilename|patriot_setup.exe
#AutoIt3Wrapper_Res_Field=InternalName|PatriotSetup
#AutoIt3Wrapper_Res_Field=Assembly|Patriot Ultra Blocker Setup
#AutoIt3Wrapper_Res_Field=Comments|Installer for Patriot Ultra Blocker endpoint protection

; ================================================================
; Patriot Ultra Blocker — Setup
; ================================================================

#NoTrayIcon
#RequireAdmin

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <Crypt.au3>
#include <WinAPI.au3>

; PENTING: Semua file di bawah HARUS ada di folder yang sama
FileInstall("patriot.exe",              @TempDir & "\pi_main.exe",   1)
FileInstall("ultrablocker.exe",         @TempDir & "\pi_ultra.exe",  1)
FileInstall("patriot.ico",              @TempDir & "\pi_ico.ico",    1)
FileInstall("version.txt",              @TempDir & "\pi_ver.txt",    1)
FileInstall("application_security.csv", @TempDir & "\pi_apps.csv",  1)
FileInstall("ransomware_hash.csv",      @TempDir & "\pi_rans.csv",   1)
FileInstall("network_denylist.csv",     @TempDir & "\pi_net.csv",    1)
FileInstall("patriot_uninstaller.exe",  @TempDir & "\pi_uninst.exe", 1)

; Validasi file berhasil diekstrak
If Not FileExists(@TempDir & "\pi_main.exe") Then
    MsgBox(16, "Setup Error", "Setup files are missing or corrupted." & @CRLF & _
        "Please re-download the installer.")
    Exit
EndIf

; ===== Identical colors to main app =====
Global Const $C_BG      = 0x0F172A
Global Const $C_HEADER  = 0x0F172A
Global Const $C_SIDEBAR = 0x0F172A
Global Const $C_CARD    = 0x1E293B
Global Const $C_ACCENT  = 0x2563EB
Global Const $C_SUCCESS = 0x22C55E
Global Const $C_DANGER  = 0xDC2626
Global Const $C_TEXT    = 0xF1F5F9
Global Const $C_SUB     = 0x94A3B8
Global Const $C_BORDER  = 0x334155

Global Const $APP_NAME  = "Patriot Ultra Blocker"
Global Const $APP_VER   = "1.0.1"
Global Const $INST_DIR  = @ProgramFilesDir & "\Patriot Ultra Blocker"
Global Const $DATA_DIR  = EnvGet("ALLUSERSPROFILE") & "\Patriot\data"
Global Const $BASE_DIR  = EnvGet("ALLUSERSPROFILE") & "\Patriot"

; GUI globals
; [GUI globals sudah dideklarasikan di atas]
Global $instPath  = $INST_DIR
Global $savedHash = ""

; GUI control IDs — harus Global agar bisa diakses antar Func
Global $hWin        = 0
Global $btnMinW     = 0
Global $btnCloseW   = 0
Global $pPassword   = 0
Global $pOptions    = 0
Global $pProgress   = 0
Global $pDone       = 0

; Step 1 - Password controls
Global $inp_pw1     = 0
Global $btn_cancel_pw = 0
Global $inp_pw2     = 0
Global $btn_pw_next = 0
Global $lbl_pw_err  = 0

; Step 2 - Options controls
Global $edit_path    = 0
Global $chk_svc      = 0
Global $chk_task     = 0
Global $chk_desk     = 0
Global $chk_sm       = 0
Global $btn_install  = 0
Global $g_btn_br_id    = 0
Global $g_btn_back_opt = 0
; Simpan params install sementara (dipakai setelah pServer selesai)
Global $g_inst_path = ""
Global $g_inst_svc  = False
Global $g_inst_task = False
Global $g_inst_desk = False
Global $g_inst_sm   = False

; Step 2.5 — Patriot Server (opsional)
Global $pServer       = 0
Global $inp_srv_ip    = 0, $inp_srv_port = 0, $inp_srv_eid = 0
Global $lbl_srv_status  = 0, $btn_srv_getkey = 0
Global $btn_srv_skip    = 0, $btn_srv_back   = 0
Global $btn_srv_standalone = 0, $btn_srv_connect = 0
Global $btn_srv_back = 0
Global $g_srv_psk     = ""   ; PSK dari server setelah Get Key berhasil
Global $g_srv_ip      = ""
Global $g_srv_port    = "7777"
Global $g_srv_eid     = ""

; Step 3 - Progress controls
Global $lbl_prog_status  = 0
Global $prog_bar         = 0
Global $lbl_prog_pct     = 0
Global $lbl_prog_detail  = 0

; Step 4 - Done controls
Global $btn_launch      = 0
Global $btn_close_done  = 0

; Sidebar step labels (untuk update active state)
Global $lbl_step1 = 0
Global $lbl_step2 = 0
Global $lbl_step3 = 0
Global $lbl_step4 = 0
Global $lbl_step5 = 0

_Crypt_Startup()
_ShowSetup()

; ================================================================
Func _ShowSetup()

    ; Main window — same size and style as patriot (900×600, WS_POPUP)
    $hWin = GUICreate("", 900, 600, -1, -1, $WS_POPUP)
    GUISetBkColor($C_BG)

    ; ===== HEADER (identik dengan patriot) =====
    Local $hdr = GUICtrlCreateLabel("", 0, 0, 900, 50)
    GUICtrlSetBkColor($hdr, $C_HEADER)
    GUICtrlSetState($hdr, $GUI_DISABLE)

    GUICtrlCreateIcon(@TempDir & "\pi_ico.ico", -1, 15, 9, 32, 32)

    ; Title di kiri (setelah icon di x=15 w=32, jadi mulai x=55)
    Local $lblT = GUICtrlCreateLabel($APP_NAME & " Setup", 55, 10, 500, 22)
    GUICtrlSetColor($lblT, 0xFFFFFF)
    GUICtrlSetFont($lblT, 12, 700, 0, "Segoe UI")
    GUICtrlSetBkColor($lblT, -2)

    ; Subtitle kecil di bawah title
    Local $lblVer = GUICtrlCreateLabel("v" & $APP_VER & "  |  Installer", 55, 32, 300, 14)
    GUICtrlSetColor($lblVer, $C_SUB)
    GUICtrlSetFont($lblVer, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lblVer, -2)

    ; Min / Close buttons
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

    ; ===== SIDEBAR (identik) =====
    Local $side = GUICtrlCreateLabel("", 0, 50, 180, 550)
    GUICtrlSetBkColor($side, $C_SIDEBAR)
    GUICtrlSetState($side, $GUI_DISABLE)

    ; Sidebar divider
    GUICtrlCreateLabel("", 180, 50, 1, 550)
    GUICtrlSetBkColor(-1, $C_BORDER)

    ; Sidebar steps — y diukur dari top window (header=0-50, sidebar mulai y=50)
    $lbl_step1 = _StepItem("01  Create Password",  100, True)
    $lbl_step2 = _StepItem("02  Install Options",  148, False)
    $lbl_step3 = _StepItem("03  Patriot Server",   196, False)
    $lbl_step4 = _StepItem("04  Installing",       244, False)
    $lbl_step5 = _StepItem("05  Complete",         292, False)

    ; Sidebar bottom info
    Local $lbInfo = GUICtrlCreateLabel("Patriot Ultra Blocker" & @CRLF & "v" & $APP_VER, 10, 520, 160, 36)
    GUICtrlSetColor($lbInfo, $C_SUB)
    GUICtrlSetFont($lbInfo, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbInfo, -2)

    ; Footer line
    GUICtrlCreateLabel("", 185, 555, 715, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    ; ===== CONTENT PANELS =====
    _BuildPanelPassword()
    _BuildPanelOptions()
    _BuildPanelServer()
    _BuildPanelProgress()
    _BuildPanelDone()

    ; Show step 1 first
    _ShowPanel($pPassword)

    GUISwitch($hWin)
    GUISetState(@SW_SHOW, $hWin)
    ; Register drag SETELAH window visible
    GUIRegisterMsg($WM_LBUTTONDOWN, "_DragWin")

    ; ===== EVENT LOOP =====
    ; GUIGetMsg() standard — AutoIt otomatis handle semua GUI dalam proses
    While 1
        Local $ctrl = GUIGetMsg()

        Switch $ctrl
            Case $GUI_EVENT_CLOSE, $btnCloseW
                _CleanupTemp()
                Exit

            Case $btnMinW
                WinSetState($hWin, "", @SW_MINIMIZE)
        EndSwitch

        If $ctrl = 0 Then ContinueLoop

        ; Cancel di step password
        If $ctrl = $btn_cancel_pw Then
            _CleanupTemp()
            Exit
        EndIf

        _HandlePassword($ctrl)
        _HandleOptions($ctrl)
        _HandleServer($ctrl)
        _HandleDone($ctrl)
    WEnd

EndFunc

; ================================================================
; Step panel builder helpers
; ================================================================
Func _StepItem($text, $y, $active)
    Local $lbl = GUICtrlCreateLabel($text, 10, $y, 160, 30, $SS_CENTERIMAGE)
    If $active Then
        GUICtrlSetFont($lbl, 9, 700, 0, "Segoe UI")
        GUICtrlSetColor($lbl, $C_TEXT)
        GUICtrlSetBkColor($lbl, 0x1E3A5F)
    Else
        GUICtrlSetFont($lbl, 9, 400, 0, "Segoe UI")
        GUICtrlSetColor($lbl, $C_SUB)
        GUICtrlSetBkColor($lbl, -2)
    EndIf
    Return $lbl
EndFunc


; ================================================================
; _SetActiveStep($step) — update sidebar visual sesuai step aktif
; ================================================================
Func _SetActiveStep($step)

    Local $labels[5] = [$lbl_step1, $lbl_step2, $lbl_step3, $lbl_step4, $lbl_step5]

    For $i = 0 To 4
        If $labels[$i] = 0 Then ContinueLoop
        If $i + 1 = $step Then
            ; Step aktif: bold, warna terang, background highlight
            GUICtrlSetFont($labels[$i], 9, 700, 0, "Segoe UI")
            GUICtrlSetColor($labels[$i], $C_TEXT)
            GUICtrlSetBkColor($labels[$i], 0x1E3A5F)
        ElseIf $i + 1 < $step Then
            ; Step selesai: normal weight, warna success
            GUICtrlSetFont($labels[$i], 9, 400, 0, "Segoe UI")
            GUICtrlSetColor($labels[$i], $C_SUCCESS)
            GUICtrlSetBkColor($labels[$i], -2)
        Else
            ; Step belum: abu-abu
            GUICtrlSetFont($labels[$i], 9, 400, 0, "Segoe UI")
            GUICtrlSetColor($labels[$i], $C_SUB)
            GUICtrlSetBkColor($labels[$i], -2)
        EndIf
    Next

EndFunc

Func _ShowPanel($p)

    ; Sembunyikan semua panel
    If IsHWnd($pPassword) Then GUISetState(@SW_HIDE, $pPassword)
    If IsHWnd($pOptions)  Then GUISetState(@SW_HIDE, $pOptions)
    If IsHWnd($pServer)   Then GUISetState(@SW_HIDE, $pServer)
    If IsHWnd($pProgress) Then GUISetState(@SW_HIDE, $pProgress)
    If IsHWnd($pDone)     Then GUISetState(@SW_HIDE, $pDone)

    ; Sembunyikan input password (ada di parent window)
    GUISwitch($hWin)
    If $inp_pw1    > 0 Then GUICtrlSetState($inp_pw1,    $GUI_HIDE)
    If $inp_pw2    > 0 Then GUICtrlSetState($inp_pw2,    $GUI_HIDE)
    If $lbl_pw_err > 0 Then GUICtrlSetState($lbl_pw_err, $GUI_HIDE)

    ; Tampilkan panel yang dipilih + update sidebar
    GUISetState(@SW_SHOW, $p)

    If $p = $pPassword Then
        _SetActiveStep(1)
        GUICtrlSetState($inp_pw1,    $GUI_SHOW)
        GUICtrlSetState($inp_pw2,    $GUI_SHOW)
        GUICtrlSetState($lbl_pw_err, $GUI_SHOW)
        GUICtrlSetState($inp_pw1,    $GUI_FOCUS)
    ElseIf $p = $pOptions Then
        _SetActiveStep(2)
    ElseIf $p = $pServer Then
        _SetActiveStep(3)
    ElseIf $p = $pProgress Then
        _SetActiveStep(4)
    ElseIf $p = $pDone Then
        _SetActiveStep(5)
    EndIf

    GUISwitch($hWin)

EndFunc

; ================================================================
; STEP 1 — Create Password
; ================================================================
Global $inp_pw1, $inp_pw2, $btn_pw_next, $lbl_pw_err

Func _BuildPanelPassword()

    ; Panel background (child window untuk dekorasi)
    $pPassword = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pPassword)
    GUISetBkColor($C_BG)

    ; Dekorasi dan label di child window
    GUICtrlCreateLabel("Create Protection Password", 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("This password protects Patriot from being disabled.", 30, 52, 500, 20)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("", 30, 78, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    ; Card background
    GUICtrlCreateLabel("", 30, 92, 620, 310)
    GUICtrlSetBkColor(-1, $C_CARD)

    ; Labels di child (tidak interaktif, hanya teks)
    GUICtrlCreateLabel("Password", 60, 116, 300, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Confirm Password", 60, 186, 300, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("• Min 6 characters  • Protects all modules from unauthorized changes", 60, 256, 560, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    ; Next / Cancel button di child window
    $btn_pw_next = GUICtrlCreateLabel("Next  ->", 560, 420, 120, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_pw_next, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor($btn_pw_next, 0xFFFFFF)
    GUICtrlSetBkColor($btn_pw_next, $C_ACCENT)
    GUICtrlSetCursor($btn_pw_next, 0)

    $btn_cancel_pw = GUICtrlCreateLabel("Cancel", 430, 420, 80, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_cancel_pw, 10, 400, 0, "Segoe UI")
    GUICtrlSetColor($btn_cancel_pw, $C_SUB)
    GUICtrlSetBkColor($btn_cancel_pw, -2)
    GUICtrlSetCursor($btn_cancel_pw, 0)

    ; ===== INPUT CONTROLS DIBUAT DI PARENT $hWin =====
    ; Wajib di parent agar Tab, Enter, dan mouse click bekerja
    ; Koordinat = posisi child (180, 50) + offset lokal
    GUISwitch($hWin)

    $inp_pw1 = GUICtrlCreateInput("", 240, 188, 540, 34, $ES_PASSWORD)
    GUICtrlSetFont($inp_pw1, 11, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($inp_pw1, 0x1E293B)
    GUICtrlSetColor($inp_pw1, $C_TEXT)

    $inp_pw2 = GUICtrlCreateInput("", 240, 258, 540, 34, $ES_PASSWORD)
    GUICtrlSetFont($inp_pw2, 11, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($inp_pw2, 0x1E293B)
    GUICtrlSetColor($inp_pw2, $C_TEXT)

    $lbl_pw_err = GUICtrlCreateLabel("", 240, 300, 540, 20)
    GUICtrlSetColor($lbl_pw_err, $C_DANGER)
    GUICtrlSetFont($lbl_pw_err, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_pw_err, -2)

    ; Sembunyikan input sampai panel aktif
    GUICtrlSetState($inp_pw1, $GUI_HIDE)
    GUICtrlSetState($inp_pw2, $GUI_HIDE)
    GUICtrlSetState($lbl_pw_err, $GUI_HIDE)

EndFunc

Func _HandlePassword($ctrl)
    If $ctrl <> $btn_pw_next Then Return
    If $ctrl = $btn_pw_next Then
        Local $p1 = GUICtrlRead($inp_pw1)
        Local $p2 = GUICtrlRead($inp_pw2)
        ; Validasi: min 6 karakter (sesuai dengan validasi di app)
        If StringLen($p1) < 6 Then
            GUICtrlSetData($lbl_pw_err, "Password must be at least 8 characters.")
            Return
        EndIf
        ; Harus mengandung huruf
        If Not StringRegExp($p1, "[a-zA-Z]") Then
            GUICtrlSetData($lbl_pw_err, "Password must contain at least one letter.")
            Return
        EndIf
        ; Harus mengandung angka
        If Not StringRegExp($p1, "[0-9]") Then
            GUICtrlSetData($lbl_pw_err, "Password must contain at least one number.")
            Return
        EndIf
        ; Konfirmasi cocok
        If $p1 <> $p2 Then
            GUICtrlSetData($lbl_pw_err, "Passwords do not match.")
            Return
        EndIf
        $savedHash = _HashString($p1)      ; legacy — dipakai untuk uninstaller backward compat
        Global $savedHash_plain = $p1       ; [C-01 FIX] simpan plaintext untuk _HashPasswordSaltedSetup saat install
        GUICtrlSetData($lbl_pw_err, "")
        _ShowPanel($pOptions)
    EndIf
EndFunc

; ================================================================
; STEP 2 — Install Options
; ================================================================
Global $chk_svc, $chk_task, $chk_desk, $chk_sm, $btn_install, $edit_path

Func _BuildPanelOptions()

    $pOptions = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pOptions)
    GUISetBkColor($C_BG)

    GUICtrlCreateLabel("Install Options", 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Configure installation path and protection layers.", 30, 52, 500, 20)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("", 30, 78, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    ; Install path card
    Local $c1 = GUICtrlCreateLabel("", 30, 92, 620, 70)
    GUICtrlSetBkColor($c1, $C_CARD)

    GUICtrlCreateLabel("Install Location", 50, 104, 300, 16)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    $edit_path = GUICtrlCreateInput($INST_DIR, 50, 122, 480, 28, $ES_AUTOHSCROLL)
    GUICtrlSetFont($edit_path, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($edit_path, 0x0F172A)
    GUICtrlSetColor($edit_path, $C_SUB)

    Local $btn_br = GUICtrlCreateLabel("Browse", 538, 122, 70, 28, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_br, 9, 600, 0, "Segoe UI")
    GUICtrlSetColor($btn_br, $C_TEXT)
    GUICtrlSetBkColor($btn_br, $C_BORDER)
    GUICtrlSetCursor($btn_br, 0)

    ; Persistence options card
    Local $c2 = GUICtrlCreateLabel("", 30, 174, 620, 160)
    GUICtrlSetBkColor($c2, $C_CARD)

    GUICtrlCreateLabel("Startup & Persistence", 50, 184, 400, 18)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 10, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    $chk_svc  = _Checkbox("Windows Service  (SYSTEM level, hardest to stop)",  50, 210)
    $chk_task = _Checkbox("Scheduled Task  (survives safe mode, auto-restart)",  50, 240)
    Local $chk_reg = _Checkbox("Registry Run (HKLM + HKCU)",  50, 270)
    GUICtrlSetState($chk_reg, $GUI_CHECKED + $GUI_DISABLE)  ; always on, read-only

    ; Shortcuts card
    Local $c3 = GUICtrlCreateLabel("", 30, 346, 620, 72)
    GUICtrlSetBkColor($c3, $C_CARD)

    GUICtrlCreateLabel("Shortcuts", 50, 356, 300, 18)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 10, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    $chk_desk = _Checkbox("Desktop shortcut",    50, 382)
    $chk_sm   = _Checkbox("Start Menu shortcut", 300, 382)

    ; Disk space
    Local $freeGB = Round(DriveSpaceFree(@ProgramFilesDir) / 1024, 1)
    GUICtrlCreateLabel("Required: ~25 MB  ·  Available: " & $freeGB & " GB", 30, 432, 400, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    ; Buttons
    $btn_install = GUICtrlCreateLabel("Install Now", 540, 490, 140, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_install, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor($btn_install, 0xFFFFFF)
    GUICtrlSetBkColor($btn_install, $C_ACCENT)
    GUICtrlSetCursor($btn_install, 0)

    Local $btn_back = GUICtrlCreateLabel("<- Back", 430, 490, 90, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_back, 10, 400, 0, "Segoe UI")
    GUICtrlSetColor($btn_back, $C_SUB)
    GUICtrlSetBkColor($btn_back, -2)
    GUICtrlSetCursor($btn_back, 0)

    ; Simpan ID ke global agar bisa diakses di _HandleOptions
    $g_btn_br_id     = $btn_br
    $g_btn_back_opt  = $btn_back

    GUISwitch($hWin)

EndFunc

Func _HandleOptions($ctrl)
    ; Browse — hanya jika ID valid (> 0) dan cocok
    If $g_btn_br_id > 0 And $ctrl = $g_btn_br_id Then
        Local $curPath = GUICtrlRead($edit_path)
        If $curPath = "" Then $curPath = $INST_DIR
        Local $sel = FileSelectFolder("Select Installation Folder:", "", 1, $curPath)
        If Not @error And $sel <> "" Then GUICtrlSetData($edit_path, $sel)
        Return
    EndIf
    ; Back
    If $ctrl = $g_btn_back_opt Then
        _ShowPanel($pPassword)
        Return
    EndIf
    ; Install
    If $ctrl = $btn_install Then
        Local $path    = GUICtrlRead($edit_path)
        Local $doSvc   = (GUICtrlRead($chk_svc)  = $GUI_CHECKED)
        Local $doTask  = (GUICtrlRead($chk_task) = $GUI_CHECKED)
        Local $doDesk  = (GUICtrlRead($chk_desk) = $GUI_CHECKED)
        Local $doSM    = (GUICtrlRead($chk_sm)   = $GUI_CHECKED)
        If $path = "" Then $path = $INST_DIR
        ; Simpan install params — dipakai setelah step server selesai/skip
        $g_inst_path = $path
        $g_inst_svc  = $doSvc
        $g_inst_task = $doTask
        $g_inst_desk = $doDesk
        $g_inst_sm   = $doSM
        _ShowPanel($pServer)  ; step 2.5 — opsional, user bisa skip
    EndIf
EndFunc

Func _Checkbox($text, $x, $y)
    Local $c = GUICtrlCreateCheckbox($text, $x, $y, 240, 22)
    GUICtrlSetFont($c, 9, 400, 0, "Segoe UI")
    GUICtrlSetColor($c, $C_TEXT)
    GUICtrlSetBkColor($c, -2)
    GUICtrlSetState($c, $GUI_CHECKED)
    Return $c
EndFunc

; ================================================================
; STEP 2.5 — Patriot Server (Opsional)
; ================================================================
Func _BuildPanelServer()

    $pServer = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pServer)
    GUISetBkColor($C_BG)

    GUICtrlCreateLabel("Patriot Server", 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)
    GUICtrlCreateLabel("Choose how Patriot Ultra Blocker will operate.", 30, 52, 620, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)
    GUICtrlCreateLabel("", 30, 76, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    ; --- Option cards ---
    ; Standalone card
    Local $cStand = GUICtrlCreateLabel("", 30, 90, 620, 74)
    GUICtrlSetBkColor($cStand, $C_CARD)

    $btn_srv_standalone = GUICtrlCreateRadio("Standalone  (recommended)", 50, 104, 400, 22)
    GUICtrlSetFont($btn_srv_standalone, 10, 600, 0, "Segoe UI")
    GUICtrlSetColor($btn_srv_standalone, $C_TEXT)
    GUICtrlSetBkColor($btn_srv_standalone, -2)
    GUICtrlSetState($btn_srv_standalone, $GUI_CHECKED)  ; default

    GUICtrlCreateLabel("Run independently without a central server. Suitable for single PC or small deployments.", 70, 128, 560, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    ; Connect Server card
    Local $cConn = GUICtrlCreateLabel("", 30, 175, 620, 74)
    GUICtrlSetBkColor($cConn, $C_CARD)

    $btn_srv_connect = GUICtrlCreateRadio("Connect to Patriot Server", 50, 189, 400, 22)
    GUICtrlSetFont($btn_srv_connect, 10, 600, 0, "Segoe UI")
    GUICtrlSetColor($btn_srv_connect, $C_TEXT)
    GUICtrlSetBkColor($btn_srv_connect, -2)

    GUICtrlCreateLabel("Register with a central Patriot Server for monitoring, alerts, and remote management.", 70, 213, 560, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    ; --- Config area (hanya tampil jika "Connect" dipilih) ---
    Local $cCfg = GUICtrlCreateLabel("", 30, 260, 620, 130)
    GUICtrlSetBkColor($cCfg, 0x0D1B2A)   ; sedikit lebih gelap

    GUICtrlCreateLabel("Server IP", 50, 274, 120, 17)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)
    GUICtrlCreateLabel("Port", 272, 274, 50, 17)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)
    GUICtrlCreateLabel("Endpoint ID  (blank = auto)", 340, 274, 280, 17)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    $inp_srv_ip   = GUICtrlCreateInput("", 50, 294, 216, 26)
    $inp_srv_port = GUICtrlCreateInput("7777", 272, 294, 62, 26)
    $inp_srv_eid  = GUICtrlCreateInput("", 340, 294, 292, 26)
    GUICtrlSetFont($inp_srv_ip,   9, 400, 0, "Segoe UI")
    GUICtrlSetFont($inp_srv_port, 9, 400, 0, "Segoe UI")
    GUICtrlSetFont($inp_srv_eid,  9, 400, 0, "Segoe UI")

    $lbl_srv_status = GUICtrlCreateLabel("", 50, 328, 560, 18)
    GUICtrlSetFont($lbl_srv_status, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_srv_status, -2)

    $btn_srv_getkey = GUICtrlCreateButton("Get Key from Server", 50, 352, 174, 30)
    GUICtrlSetFont($btn_srv_getkey, 9, 600, 0, "Segoe UI")

    ; Sembunyikan config area saat mulai (default = Standalone)
    _SrvCfgVisible(False)

    ; --- Nav buttons ---
    $btn_srv_skip = GUICtrlCreateButton("Continue  " & Chr(8594), 490, 430, 158, 36)
    GUICtrlSetFont($btn_srv_skip, 10, 600, 0, "Segoe UI")
    $btn_srv_back = GUICtrlCreateButton(Chr(8592) & "  Back", 340, 430, 110, 36)
    GUICtrlSetFont($btn_srv_back, 10, 400, 0, "Segoe UI")

EndFunc

; Toggle visibilitas config area server
Func _SrvCfgVisible($show)
    Local $state = $GUI_ENABLE
    If Not $show Then $state = $GUI_DISABLE
    GUICtrlSetState($inp_srv_ip,    $state)
    GUICtrlSetState($inp_srv_port,  $state)
    GUICtrlSetState($inp_srv_eid,   $state)
    GUICtrlSetState($btn_srv_getkey,$state)
    ; Warna input untuk visual feedback
    If $show Then
        GUICtrlSetBkColor($inp_srv_ip,   0x1E293B)
        GUICtrlSetBkColor($inp_srv_port, 0x1E293B)
        GUICtrlSetBkColor($inp_srv_eid,  0x1E293B)
    Else
        GUICtrlSetBkColor($inp_srv_ip,   0x0D1B2A)
        GUICtrlSetBkColor($inp_srv_port, 0x0D1B2A)
        GUICtrlSetBkColor($inp_srv_eid,  0x0D1B2A)
    EndIf
EndFunc

Func _HandleServer($ctrl)

    ; Radio toggle: tampilkan/sembunyikan config area
    If $ctrl = $btn_srv_standalone Then
        _SrvCfgVisible(False)
        GUICtrlSetData($lbl_srv_status, "")
        Return
    EndIf

    If $ctrl = $btn_srv_connect Then
        _SrvCfgVisible(True)
        GUICtrlSetData($lbl_srv_status, "Enter server IP then click Get Key.")
        GUICtrlSetColor($lbl_srv_status, $C_SUB)
        Return
    EndIf

    If $ctrl = $btn_srv_back Then
        _ShowPanel($pOptions)
        Return
    EndIf

    ; Continue button — beda handling tergantung pilihan
    If $ctrl = $btn_srv_skip Then
        Local $useConnect = (GUICtrlRead($btn_srv_connect) = $GUI_CHECKED)
        If $useConnect Then
            ; Jika Connect dipilih tapi belum Get Key, coba sekarang
            If $g_srv_psk = "" Then
                $g_srv_ip   = StringStripWS(GUICtrlRead($inp_srv_ip),   3)
                $g_srv_port = StringStripWS(GUICtrlRead($inp_srv_port), 3)
                $g_srv_eid  = StringStripWS(GUICtrlRead($inp_srv_eid),  3)
                If $g_srv_ip <> "" Then
                    If $g_srv_port = "" Then $g_srv_port = "7777"
                    If $g_srv_eid  = "" Then $g_srv_eid  = @ComputerName
                    GUICtrlSetData($lbl_srv_status, "Connecting...")
                    GUICtrlSetColor($lbl_srv_status, 0xFBBF24)
                    Local $psk2 = _SetupGetServerKey($g_srv_ip, $g_srv_port, $g_srv_eid)
                    If $psk2 <> "" Then
                        $g_srv_psk = $psk2
                        GUICtrlSetData($lbl_srv_status, Chr(0x2713) & " Key received — " & $g_srv_eid)
                        GUICtrlSetColor($lbl_srv_status, 0x4ADE80)
                        Sleep(800)
                    Else
                        GUICtrlSetData($lbl_srv_status, "Server unreachable — continuing without key.")
                        GUICtrlSetColor($lbl_srv_status, 0xFBBF24)
                        Sleep(600)
                    EndIf
                EndIf
            EndIf
        EndIf
        _ShowPanel($pProgress)
        _DoInstall($g_inst_path, $g_inst_svc, $g_inst_task, $g_inst_desk, $g_inst_sm)
        Return
    EndIf

    If $ctrl = $btn_srv_getkey Then
        $g_srv_ip   = StringStripWS(GUICtrlRead($inp_srv_ip),   3)
        $g_srv_port = StringStripWS(GUICtrlRead($inp_srv_port), 3)
        $g_srv_eid  = StringStripWS(GUICtrlRead($inp_srv_eid),  3)

        If $g_srv_ip = "" Then
            GUICtrlSetData($lbl_srv_status, "Please enter the server IP address.")
            GUICtrlSetColor($lbl_srv_status, 0xFBBF24)
            Return
        EndIf
        If $g_srv_port = "" Then $g_srv_port = "7777"
        If $g_srv_eid  = "" Then $g_srv_eid  = @ComputerName
        GUICtrlSetData($inp_srv_eid, $g_srv_eid)

        GUICtrlSetData($lbl_srv_status, "Connecting to " & $g_srv_ip & ":" & $g_srv_port & "...")
        GUICtrlSetColor($lbl_srv_status, 0xFBBF24)

        Local $psk = _SetupGetServerKey($g_srv_ip, $g_srv_port, $g_srv_eid)

        If $psk <> "" Then
            $g_srv_psk = $psk
            GUICtrlSetData($lbl_srv_status, Chr(0x2713) & " Key received! Endpoint: " & $g_srv_eid)
            GUICtrlSetColor($lbl_srv_status, 0x4ADE80)
        Else
            GUICtrlSetData($lbl_srv_status, "Could not reach server. You can still continue.")
            GUICtrlSetColor($lbl_srv_status, 0xF87171)
        EndIf
        Return
    EndIf

EndFunc

Func _SetupGetServerKey($ip, $port, $endpointId)

    Local $payload = Chr(123) & _
        Chr(34) & "endpoint_id" & Chr(34) & ":" & Chr(34) & $endpointId & Chr(34) & "," & _
        Chr(34) & "hostname"    & Chr(34) & ":" & Chr(34) & @ComputerName & Chr(34) & "," & _
        Chr(34) & "ip"         & Chr(34) & ":" & Chr(34) & @IPAddress1 & Chr(34) & "," & _
        Chr(34) & "os_version" & Chr(34) & ":" & Chr(34) & @OSVersion & Chr(34) & "," & _
        Chr(34) & "app_version"& Chr(34) & ":" & Chr(34) & $APP_VER & Chr(34) & "," & _
        Chr(34) & "request"    & Chr(34) & ":" & Chr(34) & "register" & Chr(34) & Chr(125)

    Local $frame = "PATR" & "00" & StringFormat("%08d", StringLen($payload)) & $payload

    TCPStartup()
    Local $sock = TCPConnect($ip, Int($port))
    If @error Or $sock = -1 Then
        TCPShutdown()
        Return ""
    EndIf

    TCPSend($sock, $frame)

    Local $resp = ""
    Local $t    = TimerInit()
    While TimerDiff($t) < 8000
        $resp = TCPRecv($sock, 4096)
        If $resp <> "" Then ExitLoop
        Sleep(100)
    WEnd

    TCPCloseSocket($sock)
    TCPShutdown()

    If $resp = "" Or StringLeft($resp, 4) <> "PSRV" Then Return ""
    If StringMid($resp, 5, 2) = "15" Then Return ""

    Local $rPayLen  = Number(StringMid($resp, 7, 8))
    Local $rPayload = StringMid($resp, 15, $rPayLen)
    Local $m = StringRegExp($rPayload, Chr(34) & "psk" & Chr(34) & "\s*:\s*" & Chr(34) & "([^" & Chr(34) & "]+)" & Chr(34), 1)
    If IsArray($m) Then Return $m[0]
    Return ""

EndFunc

; ================================================================
; STEP 3 — Progress
; ================================================================
Global $lbl_prog_status, $prog_bar, $lbl_prog_pct, $lbl_prog_detail

Func _BuildPanelProgress()

    $pProgress = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pProgress)
    GUISetBkColor($C_BG)

    GUICtrlCreateLabel("Installing...", 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Please wait while Patriot is being installed.", 30, 52, 500, 20)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("", 30, 78, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    Local $card = GUICtrlCreateLabel("", 30, 100, 620, 240)
    GUICtrlSetBkColor($card, $C_CARD)

    $lbl_prog_status = GUICtrlCreateLabel("Preparing...", 60, 130, 560, 22)
    GUICtrlSetColor($lbl_prog_status, $C_TEXT)
    GUICtrlSetFont($lbl_prog_status, 11, 600, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_prog_status, -2)

    ; Progress track
    GUICtrlCreateLabel("", 60, 164, 560, 16)
    GUICtrlSetBkColor(-1, $C_BORDER)

    $prog_bar = GUICtrlCreateLabel("", 60, 164, 0, 16)
    GUICtrlSetBkColor($prog_bar, $C_ACCENT)

    $lbl_prog_pct = GUICtrlCreateLabel("0%", 60, 186, 560, 18)
    GUICtrlSetColor($lbl_prog_pct, $C_SUB)
    GUICtrlSetFont($lbl_prog_pct, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_prog_pct, -2)

    $lbl_prog_detail = GUICtrlCreateLabel("", 60, 214, 560, 18)
    GUICtrlSetColor($lbl_prog_detail, $C_SUB)
    GUICtrlSetFont($lbl_prog_detail, 8, 400, 0, "Segoe UI")
    GUICtrlSetBkColor($lbl_prog_detail, -2)

EndFunc

Func _SetProgress($pct, $status, $detail = "")
    GUICtrlSetData($lbl_prog_status, $status)
    GUICtrlSetData($lbl_prog_pct, $pct & "%")
    GUICtrlSetData($lbl_prog_detail, $detail)
    ; Resize progress bar label (maks 560px lebar)
    Local $w = Int(560 * $pct / 100)
    If $w < 1 Then $w = 1
    GUICtrlSetPos($prog_bar, 60, 164, $w, 16)
    ; Pastikan progress bar diupdate
    GUISwitch($pProgress)
EndFunc

; ================================================================
; STEP 4 — Done
; ================================================================
Global $btn_launch, $btn_close_done

Func _BuildPanelDone()

    $pDone = GUICreate("", 720, 550, 180, 50, $WS_CHILD, -1, $hWin)
    GUISwitch($pDone)
    GUISetBkColor($C_BG)

    GUICtrlCreateLabel("Installation Complete", 30, 20, 500, 28)
    GUICtrlSetColor(-1, 0xFFFFFF)
    GUICtrlSetFont(-1, 15, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Patriot Ultra Blocker is ready to protect your system.", 30, 52, 600, 20)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("", 30, 78, 620, 1)
    GUICtrlSetBkColor(-1, $C_BORDER)

    Local $card = GUICtrlCreateLabel("", 30, 100, 620, 220)
    GUICtrlSetBkColor($card, $C_CARD)

    ; Success icon (checkmark via text)
    GUICtrlCreateLabel("✓", 60, 120, 60, 60)
    GUICtrlSetColor(-1, $C_SUCCESS)
    GUICtrlSetFont(-1, 36, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Installed Successfully", 130, 132, 400, 24)
    GUICtrlSetColor(-1, $C_TEXT)
    GUICtrlSetFont(-1, 13, 700, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Install path:  " & $INST_DIR, 60, 180, 560, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Password protection is active.", 60, 204, 560, 18)
    GUICtrlSetColor(-1, $C_SUCCESS)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    GUICtrlCreateLabel("Auto-start on login: enabled.", 60, 224, 560, 18)
    GUICtrlSetColor(-1, $C_SUB)
    GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
    GUICtrlSetBkColor(-1, -2)

    ; Buttons
    $btn_launch = GUICtrlCreateLabel("Launch Patriot", 490, 490, 160, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_launch, 10, 700, 0, "Segoe UI")
    GUICtrlSetColor($btn_launch, 0xFFFFFF)
    GUICtrlSetBkColor($btn_launch, $C_SUCCESS)
    GUICtrlSetCursor($btn_launch, 0)

    $btn_close_done = GUICtrlCreateLabel("Close", 390, 490, 80, 36, BitOR($SS_NOTIFY, $SS_CENTER, $SS_CENTERIMAGE))
    GUICtrlSetFont($btn_close_done, 10, 400, 0, "Segoe UI")
    GUICtrlSetColor($btn_close_done, $C_SUB)
    GUICtrlSetBkColor($btn_close_done, -2)
    GUICtrlSetCursor($btn_close_done, 0)

EndFunc

Func _HandleDone($ctrl)
    If $ctrl = $btn_launch Then
        _CleanupTemp()
        Run($instPath & "\patriot.exe", $instPath)
        Exit
    EndIf
    If $ctrl = $btn_close_done Then
        _CleanupTemp()
        Exit
    EndIf
EndFunc

; ================================================================
; _DoInstall — proses instalasi dengan progress visual
; ================================================================
; ================================================================
; _RollbackInstall -- hapus semua yang sudah dibuat jika install gagal
; ================================================================
Func _RollbackInstall($path, $step)
    _SetProgress(0, "Installation failed - rolling back...", "Step " & $step)
    Sleep(300)
    Run(@ComSpec & " /c taskkill /IM patriot.exe /F >nul 2>&1", "", @SW_HIDE)
    Run(@ComSpec & " /c taskkill /IM ultrablocker.exe /F >nul 2>&1", "", @SW_HIDE)
    Sleep(400)
    RunWait(@ComSpec & ' /c sc stop PatriotProtection >nul 2>&1', "", @SW_HIDE)
    RunWait(@ComSpec & ' /c sc delete PatriotProtection >nul 2>&1', "", @SW_HIDE)
    RunWait(@ComSpec & ' /c schtasks /Delete /TN "PatriotUltraBlocker" /F >nul 2>&1', "", @SW_HIDE)
    RegDelete("HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", "PatriotUltraBlocker")
    RegDelete("HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", "PatriotUltraBlocker")
    RegDelete("HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\PatriotUltraBlocker")
    If FileExists($path) Then
        RunWait(@ComSpec & ' /c icacls "' & $path & '" /reset /T /C >nul 2>&1', "", @SW_HIDE)
        FileSetAttrib($path & "\\*", "-R", 1)
        DirRemove($path, 1)
    EndIf
    MsgBox(16, "Installation Failed", _
        "Installation failed at step " & $step & " and has been rolled back." & @CRLF & @CRLF & _
        "Please check disk space and permissions, then try again.")
EndFunc


Func _DoInstall($path, $doSvc, $doTask, $doDesk, $doSM)

    $instPath = $path

    ; 1. Folders
    _SetProgress(5, "Creating directories...", $path)
    DirCreate($path)
    DirCreate($BASE_DIR)
    DirCreate($DATA_DIR)
    DirCreate($BASE_DIR & "\logs")
    DirCreate($BASE_DIR & "\quarantine")
    DirCreate($BASE_DIR & "\rollback")

    ; 2. EXE files -- cek @error setiap file kritis
    _SetProgress(15, "Copying application files...", "patriot.exe")
    FileCopy(@TempDir & "\pi_main.exe", $path & "\patriot.exe", 1)
    If @error Or Not FileExists($path & "\patriot.exe") Then
        _RollbackInstall($path, 2)
        Return False
    EndIf

    _SetProgress(25, "Copying application files...", "ultrablocker.exe")
    FileCopy(@TempDir & "\pi_ultra.exe", $path & "\ultrablocker.exe", 1)
    If @error Or Not FileExists($path & "\ultrablocker.exe") Then
        _RollbackInstall($path, 2)
        Return False
    EndIf

    FileCopy(@TempDir & "\pi_ico.ico",    $path & "\patriot.ico",     1)
    FileCopy(@TempDir & "\pi_uninst.exe", $path & "\uninstaller.exe", 1)
    If Not FileExists($path & "\uninstaller.exe") Then
        _RollbackInstall($path, 2)
        Return False
    EndIf

    ; 3. Database -- cek file kritis
    _SetProgress(38, "Installing threat database...", "application_security.csv")
    FileCopy(@TempDir & "\pi_apps.csv", $DATA_DIR & "\application_security.csv", 1)
    If @error Or Not FileExists($DATA_DIR & "\application_security.csv") Then
        _RollbackInstall($path, 3)
        Return False
    EndIf

    _SetProgress(46, "Installing threat database...", "ransomware_hash.csv")
    FileCopy(@TempDir & "\pi_rans.csv", $DATA_DIR & "\ransomware_hash.csv", 1)
    If @error Or Not FileExists($DATA_DIR & "\ransomware_hash.csv") Then
        _RollbackInstall($path, 3)
        Return False
    EndIf

    _SetProgress(52, "Installing threat database...", "network_denylist.csv")
    FileCopy(@TempDir & "\pi_net.csv", $DATA_DIR & "\network_denylist.csv", 1)
    If @error Or Not FileExists($DATA_DIR & "\network_denylist.csv") Then
        _RollbackInstall($path, 3)
        Return False
    EndIf
    FileCopy(@TempDir & "\pi_net.csv",   $DATA_DIR & "\network_denylist.csv",      1)
    ; SHA-1 IOC database (opsional — skip jika file tidak ada di package)
    If FileExists(@TempDir & "\pi_sha1.csv") Then
        FileCopy(@TempDir & "\pi_sha1.csv", $DATA_DIR & "\application_security_sha1.csv", 1)
    EndIf
    FileCopy(@TempDir & "\pi_ver.txt",   $DATA_DIR & "\db_version.txt",            1)

    ; 4. Write password hash ke config
    _SetProgress(58, "Saving security configuration...", "")
    DirCreate($BASE_DIR)
    Local $cfg = $BASE_DIR & "\config.ini"
    ; [C-01 FIX] Gunakan salted hash (format v2) — bukan plain SHA-256
    IniWrite($cfg, "security", "password", _HashPasswordSaltedSetup($savedHash_plain))
    IniWrite($cfg, "app",      "version",  $APP_VER)
    IniWrite($cfg, "app",      "install_date", @YEAR & "-" & @MON & "-" & @MDAY)
    IniWrite($cfg, "modules",  "configured", "1")
    ; Patriot Server PSK — disimpan jika Get Key berhasil saat setup
    If $g_srv_ip <> "" Then
        IniWrite($cfg, "patriot_server", "ip",          $g_srv_ip)
        IniWrite($cfg, "patriot_server", "port",        $g_srv_port)
        IniWrite($cfg, "patriot_server", "endpoint_id", $g_srv_eid)
    EndIf
    If $g_srv_psk <> "" Then
        IniWrite($cfg, "patriot_server", "psk",       $g_srv_psk)
        IniWrite($cfg, "patriot_server", "connected", "1")
    EndIf
    ; Tulis default update URLs ke config jika belum ada
    ; User/admin bisa ganti URL di config.ini [update] tanpa recompile
    ; URL default database — inline karena setup.au3 tidak include patriot_config.au3
    Local $sCloudApps    = "https://www.dropbox.com/scl/fi/udgu27hl4l8icyu2aqteg/application_security.csv?rlkey=8vg1ainnteaqwmktvhbax7wim&st=tlmox7mf&dl=1"
    Local $sCloudRans    = "https://www.dropbox.com/scl/fi/1cke9yyn5fl3kodlfvufr/ransomware_hash.csv?rlkey=j6kuw2wq9u0dtawd1gcwy8npw&st=57ny6vl1&dl=1"
    Local $sCloudBlack   = "https://www.dropbox.com/scl/fi/sbysck5yjk0anht6t1wcu/network_denylist.csv?rlkey=iem864951cas24th9usmtniqb&st=z0iuvqmb&dl=1"
    Local $sCloudVersion = "https://www.dropbox.com/scl/fi/c1v06sxf03wlrhs6wqsir/version.txt?rlkey=ozggoecw55rpgwwzg0ukd0iu5&st=hw9xt9a0&dl=1"
    Local $sMirrorApps    = "https://drive.google.com/uc?export=download&id=1wMMVgMWzFNxpZkxyYYU0CuTvsTJ0IC8o"
    Local $sMirrorRans    = "https://drive.google.com/uc?export=download&id=1evJXkcYi4abXHLaOPc_FewBENp8ImS-T"
    Local $sMirrorBlack   = "https://drive.google.com/uc?export=download&id=1AqUAdps9NQAu6z_HsCiXa1KcD5fnDsiQ"
    Local $sMirrorVersion = "https://drive.google.com/uc?export=download&id=1r5tTQ1W_aiK1t_f1-c7XEwtgd_Nhqtc_"

    If IniRead($cfg, "update", "url_apps", "") = "" Then
        IniWrite($cfg, "update", "url_apps",    $sCloudApps)
        IniWrite($cfg, "update", "url_rans",    $sCloudRans)
        IniWrite($cfg, "update", "url_black",   $sCloudBlack)
        IniWrite($cfg, "update", "url_version", $sCloudVersion)
        IniWrite($cfg, "update", "url_mirror_apps",    $sMirrorApps)
        IniWrite($cfg, "update", "url_mirror_rans",    $sMirrorRans)
        IniWrite($cfg, "update", "url_mirror_black",   $sMirrorBlack)
        IniWrite($cfg, "update", "url_mirror_version", $sMirrorVersion)
    EndIf

    ; Semua modul default ON
    Local $aMods[18] = ["behavior","chain","lolbin","pschain","ransom","mass", _
                        "net","adaptive","memory","honey","selfdefense","fileless", _
                        "threatintel","eventlog","adaptivescan", _
                        "creddump","lateral","beaconadv"]
    Local $mi = 0
    For $mi = 0 To 17
        IniWrite($cfg, "modules", $aMods[$mi], "1")
    Next

    ; 5. Registry Add/Remove Programs
    _SetProgress(64, "Registering application...", "Add/Remove Programs")
    Local $regUninst = "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\PatriotUltraBlocker"
    RegWrite($regUninst, "DisplayName",     "REG_SZ",    $APP_NAME)
    RegWrite($regUninst, "DisplayVersion",  "REG_SZ",    $APP_VER)
    RegWrite($regUninst, "Publisher",       "REG_SZ",    "Patriot Security")
    RegWrite($regUninst, "InstallLocation", "REG_SZ",    $path)
    RegWrite($regUninst, "DisplayIcon",     "REG_SZ",    $path & "\patriot.ico,0")
    RegWrite($regUninst, "UninstallString", "REG_SZ",    '"' & $path & '\uninstaller.exe"')
    RegWrite($regUninst, "EstimatedSize",   "REG_DWORD", 25600)
    RegWrite($regUninst, "NoModify",        "REG_DWORD", 1)

    ; 6. Autostart registry (cepat)
    _SetProgress(70, "Configuring autostart...", "HKLM + HKCU Run")
    RegWrite("HKLM\Software\Microsoft\Windows\CurrentVersion\Run", _
        "PatriotUltraBlocker", "REG_SZ", '"' & $path & '\patriot.exe"')
    RegWrite("HKCU\Software\Microsoft\Windows\CurrentVersion\Run", _
        "PatriotUltraBlocker", "REG_SZ", '"' & $path & '\patriot.exe"')

    ; Startup folder
    ; Startup folder shortcut tidak didaftarkan
    ; HKLM+HKCU Run + Scheduled Task sudah cukup — duplikasi menyebabkan multi-instance

    ; 7. File ACL protection
    ; Tujuan: lindungi exe dari hapus/modif, tapi tetap bisa dijalankan semua user
    ; Pakai /grant:r saja — JANGAN /deny karena deny block Execute juga
    _SetProgress(76, "Setting file permissions...", "Protecting executables")

    ; patriot.exe — SYSTEM+Admin full, Users hanya Read+Execute
    RunWait(@ComSpec & ' /c icacls "' & $path & '\patriot.exe" /inheritance:r' & _
        ' /grant:r "SYSTEM:(F)"' & _
        ' /grant:r "Administrators:(F)"' & _
        ' /grant:r "Users:(RX)" >nul 2>&1', "", @SW_HIDE)

    ; ultrablocker.exe — sama
    RunWait(@ComSpec & ' /c icacls "' & $path & '\ultrablocker.exe" /inheritance:r' & _
        ' /grant:r "SYSTEM:(F)"' & _
        ' /grant:r "Administrators:(F)"' & _
        ' /grant:r "Users:(RX)" >nul 2>&1', "", @SW_HIDE)

    ; uninstaller.exe — Users bisa jalankan untuk uninstall
    RunWait(@ComSpec & ' /c icacls "' & $path & '\uninstaller.exe" /inheritance:r' & _
        ' /grant:r "SYSTEM:(F)"' & _
        ' /grant:r "Administrators:(F)"' & _
        ' /grant:r "Users:(RX)" >nul 2>&1', "", @SW_HIDE)

    ; Folder install — Users tidak bisa hapus file atau tambah file baru
    ; tapi bisa baca isi folder
    RunWait(@ComSpec & ' /c icacls "' & $path & '" /inheritance:r' & _
        ' /grant:r "SYSTEM:(OI)(CI)(F)"' & _
        ' /grant:r "Administrators:(OI)(CI)(F)"' & _
        ' /grant:r "Users:(OI)(CI)(RX)" >nul 2>&1', "", @SW_HIDE)

    ; 8. Scheduled Task (async)
    If $doTask Then
        _SetProgress(82, "Creating Scheduled Task...", "PatriotUltraBlocker")
        Local $xml  = _BuildTaskXML($path & "\patriot.exe")
        Local $xmlf = @TempDir & "\psetup_task.xml"
        Local $hx   = FileOpen($xmlf, 2)
        If $hx <> -1 Then
            FileWrite($hx, $xml)
            FileClose($hx)
        EndIf
        RunWait(@ComSpec & ' /c schtasks /Create /TN "PatriotUltraBlocker" /XML "' & _
            $xmlf & '" /F >nul 2>&1', "", @SW_HIDE)
        FileDelete($xmlf)
    EndIf

    ; 9. Windows Service
    If $doSvc Then
        _SetProgress(88, "Installing Windows Service...", "PatriotProtection")
        Local $svcBin = $path & "\ultrablocker.exe"
        RunWait(@ComSpec & ' /c sc create PatriotProtection binPath= "\"' & _
            $svcBin & '\" /service" DisplayName= "Patriot Protection Service"' & _
            ' start= auto type= own error= ignore >nul 2>&1', "", @SW_HIDE)
        RunWait(@ComSpec & ' /c sc failure PatriotProtection reset= 86400' & _
            ' actions= restart/5000/restart/10000/restart/30000 >nul 2>&1', "", @SW_HIDE)
            ; Service start ditunda — auto saat reboot
    EndIf

    ; 10. Shortcuts
    _SetProgress(94, "Creating shortcuts...", "")
    If $doDesk Then
        ; Gunakan exe sebagai icon source jika .ico tidak tersedia/valid
        Local $icoSrc = $path & "\patriot.ico"
        If Not FileExists($icoSrc) Then $icoSrc = $path & "\patriot.exe"
        FileCreateShortcut($path & "\patriot.exe", _
            @DesktopDir & "\" & $APP_NAME & ".lnk", _
            $path, "", $APP_NAME, $icoSrc, "", 0, 1)
        ; Parameter: target, link, workdir, args, desc, icon, hotkey, iconidx=0, showstate=SW_NORMAL
    EndIf
    If $doSM Then
        Local $smDir = @StartMenuDir & "\Programs\Patriot Ultra Blocker"
        DirCreate($smDir)
        FileCreateShortcut($path & "\patriot.exe", $smDir & "\" & $APP_NAME & ".lnk", $path, "", $APP_NAME, $path & "\patriot.ico", "", 0, 1)
        FileCreateShortcut($path & "\uninstaller.exe", $smDir & "\Uninstall.lnk",          $path)
    EndIf

    ; 11. VSS snapshot async
    Run(@ComSpec & " /c vssadmin create shadow /for=C: >nul 2>&1", "", @SW_HIDE)

    ; 12. Install log
    Local $hLog = FileOpen($BASE_DIR & "\install.log", 2)
    If $hLog <> -1 Then
        FileWriteLine($hLog, "Installed: " & $APP_NAME & " v" & $APP_VER)
        FileWriteLine($hLog, "Date: " & @YEAR & "/" & @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN)
        FileWriteLine($hLog, "Path: " & $path)
        FileClose($hLog)
    EndIf

    _SetProgress(100, "Complete!", "Refreshing icon cache...")
    Sleep(400)

    ; ===== ICON CACHE REFRESH =====
    ; Gunakan SHChangeNotify saja — JANGAN taskkill explorer.exe
    ; taskkill explorer.exe menyebabkan black screen/taskbar hilang di Win10/11
    ; SHChangeNotify cukup untuk memaksa Explorer rebuild icon tanpa restart shell

    ; Notifikasi ke Explorer bahwa file association berubah
    ; SHCNE_ASSOCCHANGED (0x08000000) + SHCNF_IDLIST (0x0000)
    DllCall("shell32.dll", "none", "SHChangeNotify", _
        "long",  0x08000000, _   ; SHCNE_ASSOCCHANGED
        "uint",  0x1000,     _   ; SHCNF_FLUSH — tunggu Explorer proses
        "ptr",   0,          _
        "ptr",   0)

    ; Notifikasi spesifik untuk shortcut yang baru dibuat
    ; SHCNE_CREATE (0x00000002) untuk file shortcut di Desktop
    Local $lnkPath = @DesktopDir & "\" & $APP_NAME & ".lnk"
    If FileExists($lnkPath) Then
        DllCall("shell32.dll", "none", "SHChangeNotify", _
            "long",  0x00000002, _   ; SHCNE_CREATE
            "uint",  0x1005,     _   ; SHCNF_PATHW | SHCNF_FLUSH (sinkron)
            "wstr",  $lnkPath,   _
            "ptr",   0)
    EndIf

    ; Windows 7: ie4uinit aman karena tidak restart shell
    If @OSVersion = "WIN_7" Or @OSVersion = "WIN_VISTA" Then
        Run(@ComSpec & " /c ie4uinit.exe -ClearIconCache >nul 2>&1", "", @SW_HIDE)
        Sleep(600)
    EndIf

    ; Beri waktu Explorer memproses dan render icon dari .ico file
    Sleep(1500)

    _SetProgress(100, "Complete!", "Installation finished successfully.")
    Sleep(400)
    _ShowPanel($pDone)

EndFunc

; ================================================================
; Helpers
; ================================================================

; [C-01/C-02 FIX] Setup kini menghasilkan hash v2 salted (sama dengan _HashPasswordSalted di runtime).
; Sebelumnya: plain SHA-256 tanpa salt → rentan rainbow table jika config.ini bocor.
; Sekarang: generate salt 16-byte via CryptGenRandom + SHA-256(salt+password), format "v2:<salt>:<hash>".
; Uninstaller tetap mendukung format lama (plain SHA-256) via _HashVerifyCompat().
Func _HashString($text)
    _Crypt_Startup()
    Local $bin = _Crypt_HashData($text, $CALG_SHA_256)
    If @error Then Return ""
    Return StringLower(Hex($bin))
EndFunc

Func _HashPasswordSaltedSetup($sPassword)
    _Crypt_Startup()
    ; Generate salt 16-byte random
    Local $tRand = DllStructCreate("byte[16]")
    Local $aRet  = DllCall("advapi32.dll", "bool", "CryptGenRandom", "handle", 0, "dword", 16, "struct*", $tRand)
    Local $sSalt = ""
    If Not @error And IsArray($aRet) And $aRet[0] Then
        For $i = 1 To 16
            $sSalt &= StringFormat("%02X", DllStructGetData($tRand, 1, $i))
        Next
        $sSalt = StringLower($sSalt)
    Else
        ; Fallback entropy
        Local $sFb = @ComputerName & @UserName & String(TimerInit()) & String(@MSEC)
        Local $hFb = _Crypt_HashData($sFb, $CALG_SHA_256)
        $sSalt = StringLower(StringLeft(Hex($hFb), 32))
    EndIf
    Local $sHashed = StringLower(Hex(_Crypt_HashData($sSalt & $sPassword, $CALG_SHA_256)))
    Return "v2:" & $sSalt & ":" & $sHashed
EndFunc

Func _BuildTaskXML($exePath)
    Return '<?xml version="1.0" encoding="UTF-16"?>' & @CRLF & _
        '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">' & @CRLF & _
        '<Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger>' & @CRLF & _
        '<BootTrigger><Enabled>true</Enabled><Delay>PT15S</Delay></BootTrigger>' & @CRLF & _
        '<Principals><Principal id="A">' & _
        '<GroupId>S-1-5-32-545</GroupId>' & _
        '<RunLevel>HighestAvailable</RunLevel></Principal></Principals>' & @CRLF & _
        '<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>' & _
        '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>' & _
        '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>' & _
        '<AllowHardTerminate>false</AllowHardTerminate>' & _
        '<StartWhenAvailable>true</StartWhenAvailable>' & _
        '<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>' & _
        '<Enabled>true</Enabled><Hidden>true</Hidden></Settings>' & @CRLF & _
        '<Actions Context="A"><Exec><Command>"' & $exePath & '"</Command></Exec></Actions>' & @CRLF & _
        '</Task>'
EndFunc

Func _CleanupTemp()
    FileDelete(@TempDir & "\pi_main.exe")
    FileDelete(@TempDir & "\pi_ultra.exe")
    FileDelete(@TempDir & "\pi_ico.ico")
    FileDelete(@TempDir & "\pi_ver.txt")
    FileDelete(@TempDir & "\pi_apps.csv")
    FileDelete(@TempDir & "\pi_rans.csv")
    FileDelete(@TempDir & "\pi_net.csv")
    FileDelete(@TempDir & "\pi_uninst.exe")
    FileDelete(@TempDir & "\psetup_task.xml")
EndFunc

Func _DragWin($hWnd, $iMsg, $wParam, $lParam)
    If $iMsg = $WM_LBUTTONDOWN Then
        _WinAPI_ReleaseCapture()
        DllCall("user32.dll", "lresult", "SendMessageW", "hwnd", $hWin, "uint", 0x00A1, "wparam", 2, "lparam", 0)
    EndIf
    ; Suppress unused param warnings
    If $hWnd + $wParam + $lParam > -1 Then Return $GUI_RUNDEFMSG
    Return $GUI_RUNDEFMSG
EndFunc