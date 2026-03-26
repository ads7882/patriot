#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=patriot.ico
#AutoIt3Wrapper_Outfile=ultrablocker.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_Res_Comment=Patriot Ultra Blocker
#AutoIt3Wrapper_Res_Description=Patriot Ultra Blocker — Guardian Service
#AutoIt3Wrapper_Res_Fileversion=1.0.1.0
#AutoIt3Wrapper_Res_ProductName=Patriot Ultra Blocker
#AutoIt3Wrapper_Res_ProductVersion=1.0.1.0
#AutoIt3Wrapper_Res_CompanyName=Think-C
#AutoIt3Wrapper_Res_LegalCopyright=Copyright © 2026 Think-C. All rights reserved.
#AutoIt3Wrapper_Res_SaveSource=y
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AutoIt3Wrapper_Res_Field=FileDescription|Patriot Ultra Blocker — Guardian Service
#AutoIt3Wrapper_Res_Field=ProductName|Patriot Ultra Blocker
#AutoIt3Wrapper_Res_Field=CompanyName|Think-C
#AutoIt3Wrapper_Res_Field=LegalCopyright|Copyright © 2026 Think-C. All rights reserved.
#AutoIt3Wrapper_Res_Field=OriginalFilename|ultrablocker.exe
#AutoIt3Wrapper_Res_Field=InternalName|PatriotGuardian
#AutoIt3Wrapper_Res_Field=Assembly|Patriot Ultra Blocker Guardian
#AutoIt3Wrapper_Res_Field=Comments|Watchdog & headless scan engine for Patriot Ultra Blocker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
; ================================================================
; ultrablocker.au3  —  Patriot Ultra Blocker  |  Guardian Process
; ================================================================
; Peran: proses latar (watchdog) yang memastikan patriot.exe
; tetap berjalan dan melakukan scanning mandiri jika diperlukan.
;
; File ini BUKAN duplikat patriot.au3. Ia hanya berisi:
;   • Mode /guardian2  → watchdog murni: pantau & restart patriot.exe
;   • Mode /service    → scanning engine tanpa GUI (headless EDR)
;   • Tanpa GUI, tanpa tray icon, tanpa panel, tanpa event loop GUI
;
; Siklus hidup normal:
;   patriot.exe (main GUI)  →  spawn  →  ultrablocker.exe
;   ultrablocker.exe (/guardian2) memantau patriot.exe via sentinel PID,
;   dan jika patriot.exe mati (crash/kill), ia restart otomatis.
; ================================================================

; ===== AutoIt3Wrapper directives =====
#AutoIt3Wrapper_Icon=patriot.ico
#AutoIt3Wrapper_OutFile=ultrablocker.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Run_Au3Check=y
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=n

; ===== File Version Info =====
#AutoIt3Wrapper_Res_FileVersion=1.0.1.0
#AutoIt3Wrapper_Res_FileVersion_AutoIncrement=n
#AutoIt3Wrapper_Res_ProductVersion=1.0.1.0
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AutoIt3Wrapper_Res_Field=FileDescription|Patriot Ultra Blocker — Guardian Service
#AutoIt3Wrapper_Res_Field=ProductName|Patriot Ultra Blocker
#AutoIt3Wrapper_Res_Field=CompanyName|Think-C
#AutoIt3Wrapper_Res_Field=LegalCopyright|Copyright © 2026 Think-C. All rights reserved.
#AutoIt3Wrapper_Res_Field=OriginalFilename|ultrablocker.exe
#AutoIt3Wrapper_Res_Field=InternalName|PatriotGuardian
#AutoIt3Wrapper_Res_Field=Assembly|Patriot Ultra Blocker Guardian
#AutoIt3Wrapper_Res_Field=Comments|Watchdog & headless scan engine for Patriot Ultra Blocker
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator

; ================================================================
; INCLUDES — hanya yang benar-benar dipakai guardian/service
; Tidak include patriot_gui.au3 karena guardian tidak punya GUI
; ================================================================
#RequireAdmin
#NoTrayIcon

#include <File.au3>
#include <Array.au3>
#include <Crypt.au3>
#include <WinAPI.au3>
#include <Date.au3>
#include <Misc.au3>
#include <Process.au3>

#include "lib\patriot_config.au3"
#include "lib\patriot_globals.au3"
#include "lib\patriot_log.au3"
#include "lib\patriot_db.au3"
#include "lib\patriot_network.au3"
#include "lib\patriot_rollback.au3"
#include "lib\patriot_engine.au3"
#include "lib\patriot_detect.au3"
; patriot_gui.au3 TIDAK di-include — guardian tidak butuh GUI

; ================================================================
; INISIALISASI MINIMAL
; ================================================================
Opt("GUIOnEventMode", 0)
Opt("TrayAutoPause",  0)
Opt("TrayIconHide",   1)  ; guardian tidak punya tray icon

AutoItWinSetTitle("Patriot Guardian")

_Crypt_Startup()
OnAutoItExitRegister("_GuardianCleanup")

; Pastikan folder data ada sebelum logging
DirCreate($BASE_DIR)
DirCreate($DATA_DIR)
DirCreate($LOG_DIR)

; ================================================================
; ROUTING BERDASARKAN ARGUMEN — entry point tunggal
; ================================================================
If $CmdLine[0] = 0 Then
    ; Tanpa argumen → jalankan sebagai guardian2 (default perilaku
    ; saat diluncurkan langsung oleh patriot.exe tanpa argumen)
    _RunAsGuardian2()
    Exit
EndIf

Switch StringLower($CmdLine[1])
    Case "/guardian", "/guardian1"
        _RunAsGuardian1()
    Case "/guardian2"
        _RunAsGuardian2()
    Case "/service"
        _RunAsService()
    Case Else
        ; Argumen tidak dikenal — exit diam
        Exit
EndSwitch

Exit

; ================================================================
; MODE 1 — GUARDIAN1
; Dipanggil oleh: patriot.exe /guardian (via @ScriptFullPath)
; Tugas: pantau patriot.exe + pastikan ultrablocker.exe tetap hidup
;
; Catatan: Guardian1 dijalankan dari patriot.exe dengan /guardian,
; sehingga @ScriptFullPath = patriot.exe bukan ultrablocker.exe.
; Guardian1 memonitor proses main GUI dan spawn guardian2 jika mati.
; ================================================================
Func _RunAsGuardian1()

    ; Singleton — tolak instance ganda
    If _Singleton("UB_GUARDIAN1", 1) = 0 Then Exit

    _GuardianLog("Guardian1 started (PID=" & @AutoItPID & ")")

    ; Tunggu main process selesai init
    Sleep(4000)

    Local $mainExe   = "patriot.exe"
    Local $g2name    = "ultrablocker.exe"
    Local $g2path    = @ProgramFilesDir & "\Patriot Ultra Blocker\ultrablocker.exe"
    If Not FileExists($g2path) Then $g2path = @ScriptDir & "\ultrablocker.exe"

    Local $mainPath  = @ProgramFilesDir & "\Patriot Ultra Blocker\patriot.exe"
    If Not FileExists($mainPath) Then $mainPath = @ScriptDir & "\patriot.exe"

    Local $restartCount   = 0
    Local $lastRestartTime = 0

    While 1

        ; === Cek main process (patriot.exe) ===
        Local $mainRunning = False
        Local $plist = ProcessList($mainExe)
        For $i = 1 To $plist[0][0]
            If $plist[$i][1] = @AutoItPID Then ContinueLoop  ; skip diri sendiri
            $mainRunning = True
            ExitLoop
        Next

        If Not $mainRunning Then

            ; Throttle restart: maks 1 restart per 10 detik
            If $lastRestartTime = 0 Or TimerDiff($lastRestartTime) > 10000 Then

                $restartCount  += 1
                $lastRestartTime = TimerInit()
                _GuardianLog("Guardian1: patriot.exe tidak ditemukan — restart #" & $restartCount)

                If FileExists($mainPath) Then
                    Run('"' & $mainPath & '"', "", @SW_HIDE)
                    Sleep(6000)
                Else
                    _GuardianLog("Guardian1: WARN — patriot.exe tidak ditemukan di " & $mainPath)
                EndIf

            EndIf

            ContinueLoop

        EndIf

        ; === Cek guardian2 (ultrablocker.exe) ===
        If Not ProcessExists($g2name) Then
            If FileExists($g2path) Then
                _GuardianLog("Guardian1: ultrablocker.exe mati — respawn")
                Run('"' & $g2path & '"', "", @SW_HIDE)
                Sleep(3000)
            EndIf
        EndIf

        Sleep(3000)

    WEnd

EndFunc

; ================================================================
; MODE 2 — GUARDIAN2 (default mode ultrablocker.exe)
; Dipanggil oleh: patriot.exe atau service
; Tugas: pantau patriot.exe via sentinel PID file
;        Jika sentinel hilang atau PID mati → restart patriot.exe
;
; Menggunakan sentinel file ($SENTINEL_FILE) yang ditulis patriot.exe
; saat startup dan dihapus saat exit normal. Jika file ada tapi PID
; mati → crash terdeteksi → restart.
; ================================================================
Func _RunAsGuardian2()

    ; Singleton — tolak instance ganda
    If _Singleton("UB_GUARDIAN2", 1) = 0 Then Exit

    _GuardianLog("Guardian2 started (PID=" & @AutoItPID & ")")

    ; Tunggu sistem stabil setelah boot/login
    Sleep(5000)

    Local $mainPath = @ProgramFilesDir & "\Patriot Ultra Blocker\patriot.exe"
    If Not FileExists($mainPath) Then $mainPath = @ScriptDir & "\patriot.exe"

    Local $restartCount    = 0
    Local $lastRestartTime = 0
    Local $consecFail      = 0   ; consecutive failures — untuk backoff

    While 1

        Local $mainAlive = _CheckMainAlive()

        If Not $mainAlive Then

            $consecFail += 1

            ; Backoff eksponensial: gagal berulang → tunggu lebih lama
            ; (maks 60 detik) sebelum restart berikutnya
            Local $backoffMs = Min(60000, 5000 * $consecFail)

            If $lastRestartTime = 0 Or TimerDiff($lastRestartTime) > $backoffMs Then

                $restartCount   += 1
                $lastRestartTime = TimerInit()

                _GuardianLog("Guardian2: patriot.exe tidak aktif — restart #" & $restartCount & _
                    " (backoff=" & Int($backoffMs / 1000) & "s)")

                If FileExists($mainPath) Then
                    Run('"' & $mainPath & '"', "", @SW_HIDE)
                    ; Tunggu sampai sentinel ditulis (max 15 detik)
                    _WaitForSentinel(15000)
                    If _CheckMainAlive() Then
                        $consecFail = 0
                        _GuardianLog("Guardian2: restart berhasil")
                    EndIf
                Else
                    _GuardianLog("Guardian2: CRITICAL — patriot.exe tidak ditemukan di " & $mainPath)
                    ; Tidak bisa restart → tunggu lebih lama
                    Sleep(30000)
                EndIf

            EndIf

        Else
            ; Main hidup — reset counter kegagalan
            $consecFail = 0
        EndIf

        Sleep(3000)

    WEnd

EndFunc

; ================================================================
; MODE 3 — SERVICE (headless scanning engine)
; Dipanggil oleh: Windows Service atau saat patriot.exe tidak ada
; Tugas: jalankan engine deteksi tanpa GUI
;        Berguna saat patriot.exe belum startup atau di lingkungan
;        non-interactive (session 0, Windows Server headless)
; ================================================================
Func _RunAsService()

    _GuardianLog("Service mode started (PID=" & @AutoItPID & ")")

    ; Load data yang dibutuhkan engine
    _Crypt_Startup()
    _InitWMI()
    _LoadDBVersion()
    _LoadDB()
    _LoadWhitelist()
    _LoadBaseline()
    _LoadTrustModel()
    _LoadHashCache()

    ; Aktifkan scanning via Adlib (non-blocking, CPU-friendly)
    $bIsBlocking = True

    AdlibRegister("_RefreshProcSnapshot", 1500)
    AdlibRegister("_Monitor",             $SCAN_INTERVAL)
    AdlibRegister("_HashWatcher",         2000)
    AdlibRegister("_RansomFastScan",      3000)
    AdlibRegister("_DecayAI",             10000)
    AdlibRegister("_AdaptiveScanRate",    60000)
    AdlibRegister("_VerifyKillPending",   2000)
    AdlibRegister("_BackupRollbackFolders", $g_BackupIntervalMin * 60000)
    AdlibRegister("_AutoUpdateDB",        86400000)  ; update DB sekali sehari

    _GuardianLog("Service: scanning engine aktif — scan interval=" & $SCAN_INTERVAL & "ms")

    ; Idle loop — semua kerja dilakukan Adlib
    While 1
        Sleep(1000)
    WEnd

EndFunc

; ================================================================
; HELPERS
; ================================================================

; Cek apakah main GUI (patriot.exe) hidup via sentinel PID file
Func _CheckMainAlive()
    If Not FileExists($SENTINEL_FILE) Then Return False
    Local $savedPID = Int(StringStripWS(FileRead($SENTINEL_FILE), 8))
    If $savedPID <= 0 Then Return False
    Return ProcessExists($savedPID)
EndFunc

; Tunggu sentinel file ditulis oleh patriot.exe (max $timeoutMs)
Func _WaitForSentinel($timeoutMs)
    Local $t = TimerInit()
    While TimerDiff($t) < $timeoutMs
        If _CheckMainAlive() Then Return True
        Sleep(500)
    WEnd
    Return False
EndFunc

; Min helper (AutoIt tidak punya built-in Min untuk angka)
Func Min($a, $b)
    Return ($a < $b) ? $a : $b
EndFunc

; Log khusus guardian — tidak perlu GUI list, hanya tulis ke file
Func _GuardianLog($msg)
    Local $file = $LOG_DIR & @YEAR & "-" & @MON & "-" & @MDAY & ".log"
    If Not FileExists($LOG_DIR) Then DirCreate($LOG_DIR)
    Local $h = FileOpen($file, 1)
    If $h <> -1 Then
        FileWriteLine($h, _NowCalc() & "|GUARDIAN|" & $msg & "|INFO")
        FileClose($h)
    EndIf
EndFunc

; Cleanup saat guardian exit
Func _GuardianCleanup()
    _Crypt_Shutdown()
EndFunc

; ================================================================
; STUB FUNCTIONS — diperlukan karena patriot_engine.au3 memanggil
; beberapa fungsi GUI yang tidak ada di guardian (karena patriot_gui.au3
; tidak di-include). Stub ini mencegah runtime error.
; ================================================================

; GUI update stubs — guardian tidak punya GUI, abaikan saja
Func _UpdateOverview()         Return  EndFunc
Func _UpdateAppsGUI()          Return  EndFunc
Func _UpdateRansGUI()          Return  EndFunc
Func _UpdateBlackGUI()         Return  EndFunc
Func _UpdateThreatNetwork()    Return  EndFunc
Func _UpdateProtectionCard()   Return  EndFunc
Func _UpdateAnalytics()        Return  EndFunc

; Log stub — gunakan _GuardianLog langsung jika dipanggil dari engine
Func _LogDecision($name, $path, $reason, $action)
    _GuardianLog("DECISION|" & $name & "|" & $action & " (" & $reason & ")")
EndFunc

; Toast stub — guardian tidak tampilkan notifikasi
Func _ToastNotify($title, $msg, $type = 1)
    _GuardianLog("NOTIFY|" & $title & ": " & $msg)
EndFunc

; Tray tip stub
Func TrayTip_stub($title, $msg, $timeout = 5, $icon = 1)
    _GuardianLog("TRAYTIP|" & $title & ": " & $msg)
EndFunc

; Password dialog stub — guardian tidak punya GUI untuk dialog
Func _PasswordDialog($title, $confirm = False)
    Local $r[2] = ["", ""]
    Return $r
EndFunc

; Whitelist add stubs
Func _WhitelistAddFile()    Return  EndFunc
Func _WhitelistAddFolder()  Return  EndFunc

; Quarantine action stubs
Func _QuarActionMulti($action)   Return  EndFunc
Func _WhiteRemoveMulti()         Return  EndFunc

; Rollback load stubs (load data tapi tidak update GUI)
Func _LoadRollbackFolders()  Return  EndFunc
Func _LoadRollbackFiles()    Return  EndFunc

; Startup / persistence — dijalankan patriot.exe, bukan guardian
Func _OnStartupComplete()    Return  EndFunc
Func _StartupShowFallback()  Return  EndFunc

; Export stubs
Func _ExportDailyLog()    Return  EndFunc
Func _ExportThreatCSV()   Return  EndFunc
