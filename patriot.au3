; #AutoIt3Wrapper directives — embed file properties into compiled exe
#AutoIt3Wrapper_Icon=patriot.ico
#AutoIt3Wrapper_OutFile=patriot.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Run_Au3Check=y
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=n

; === File Version Info (File Properties di Windows Explorer) ===
#AutoIt3Wrapper_Res_FileVersion=1.0.1.0
#AutoIt3Wrapper_Res_FileVersion_AutoIncrement=n
#AutoIt3Wrapper_Res_ProductVersion=1.0.1.0
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator

; === String Table (tampil di Properties > Details) ===
#AutoIt3Wrapper_Res_Field=FileDescription|Patriot Ultra Blocker — Endpoint Protection
#AutoIt3Wrapper_Res_Field=ProductName|Patriot Ultra Blocker
#AutoIt3Wrapper_Res_Field=CompanyName|Think-C
#AutoIt3Wrapper_Res_Field=LegalCopyright|Copyright © 2026 Think-C. All rights reserved.
#AutoIt3Wrapper_Res_Field=OriginalFilename|patriot.exe
#AutoIt3Wrapper_Res_Field=InternalName|PatriotUltraBlocker
#AutoIt3Wrapper_Res_Field=Assembly|Patriot Ultra Blocker
#AutoIt3Wrapper_Res_Field=Comments|Advanced endpoint protection against ransomware and malware

; === UAC manifest (sudah di-handle #RequireAdmin, ini double protection) ===
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator

; ========== HEADER ==========
#RequireAdmin
#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <WindowsConstants.au3>
#include <File.au3>
#include <Array.au3>
#include <GuiListView.au3>
#include <Crypt.au3>
#include <WinAPI.au3>
#include <Date.au3>
#include <Inet.au3>
#include <TrayConstants.au3>
#include <StaticConstants.au3>
#include <TabConstants.au3>
#include <WinAPIConstants.au3>
#include <EditConstants.au3>
#include <Misc.au3>
#include <Process.au3>

; ========== CONFIG & GLOBALS ==========
#include "lib\patriot_config.au3"
#include "lib\patriot_globals.au3"
#include "lib\patriot_log.au3"
#include "lib\patriot_db.au3"
#include "lib\patriot_network.au3"
#include "lib\patriot_rollback.au3"
#include "lib\patriot_engine.au3"
#include "lib\patriot_detect.au3"
#include "lib\patriot_gui.au3"

; Runtime setup — harus setelah include agar $BASE_DIR sudah terdefinisi
Opt("GUIOnEventMode",0)
Opt("TrayAutoPause",0)

; [FIX-TASKMAN] Set window title internal AutoIt → nama yang muncul di Task Manager
; Tanpa ini, Task Manager menampilkan "aut2exe" (nama default AutoIt compiled exe).
AutoItWinSetTitle("Patriot Ultra Blocker")

_Crypt_Startup()
OnAutoItExitRegister("_Cleanup")

DirCreate($BASE_DIR)
DirCreate($DATA_DIR)
DirCreate($sQuarDir)
DirCreate($LOG_DIR)
DirCreate($ROLLBACK_DIR)
; ================================================================
; EARLY EXIT
; ================================================================
If $CmdLine[0] > 0 Then
    Switch StringLower($CmdLine[1])
        Case "/guardian"
            Opt("TrayIconHide", 1)  ; Sembunyikan tray SEBELUM apapun
            _GuardianLoop()
            Exit
        Case "/guardian2"
            Opt("TrayIconHide", 1)  ; Sembunyikan tray SEBELUM apapun
            _GuardianLoop2()
            Exit
        Case "/service"
            Opt("TrayIconHide", 1)
            _ServiceMode()
            Exit
    EndSwitch
EndIf

; Singleton — hanya 1 main instance
If _Singleton("PatriotUltraBlocker", 1) = 0 Then
    Local $hExist = WinGetHandle("Patriot Ultra Blocker")
    If $hExist <> "" Then WinActivate($hExist)
    Exit
EndIf

_WritePIDSentinel()

; Anti-flicker via LockWindowUpdate + RedrawWindow saja
Global $hGUI = GUICreate("", 900, 600, -1, -1, $WS_POPUP)
GUISetBkColor($COLOR_BG)

; Set main window handle for use in includes
Global $hMain = $hGUI

; ========== CUSTOM HEADER ==========
Global $HEADER_H = 50

Global $header = GUICtrlCreateLabel("",0,0,900,$HEADER_H)
GUICtrlSetBkColor(-1,$COLOR_HEADER)
GUICtrlSetState($header, $GUI_DISABLE)

Global $idListToolLogo = GUICtrlCreateIcon(@ScriptDir & "\patriot.ico", -1, 15, 9, 32, 32)

Global $lblTitle = GUICtrlCreateLabel("Patriot Ultra Blocker",60,14,300,20)
GUICtrlSetBkColor($lblTitle, -2) ; transparent
GUICtrlSetColor(-1,0xFFFFFF)
GUICtrlSetFont(-1,14,700,0,"Segoe UI")

$btnMin = GUICtrlCreateLabel("—",800,0,50,$HEADER_H, BitOR($SS_NOTIFY,$SS_CENTER,$SS_CENTERIMAGE))
GUICtrlSetFont($btnMin,14,700,0,"Segoe UI")
GUICtrlSetColor($btnMin,$COLOR_TEXT)
GUICtrlSetCursor($btnMin,0)
GUICtrlSetBkColor($btnMin,$COLOR_HEADER)

$btnClose = GUICtrlCreateLabel("✕",850,0,50,$HEADER_H, BitOR($SS_NOTIFY,$SS_CENTER,$SS_CENTERIMAGE))
GUICtrlSetFont($btnClose,14,700,0,"Segoe UI")
GUICtrlSetColor($btnClose,$COLOR_TEXT)
GUICtrlSetCursor($btnClose,0)
GUICtrlSetBkColor($btnClose,$COLOR_HEADER)

; 1. Sidebar Background (Gunakan $SS_BLACKRECT atau disable label)
Global $sidebar = GUICtrlCreateLabel("", 0, $HEADER_H, 180, 600-$HEADER_H)
GUICtrlSetBkColor($sidebar, $COLOR_SIDEBAR)
GUICtrlSetState($sidebar, $GUI_DISABLE)
GUICtrlCreateLabel("",180,$HEADER_H,1,600-$HEADER_H)
GUICtrlSetBkColor(-1,0x334155)

GUICtrlCreateLabel("",190,550,900,1)
GUICtrlSetBkColor(-1,0x334155)
Global $lblUpdate = _FooterBtn("Synchronize",600,560,239)
Global $lblPwd    = _FooterBtn("Change Password",750,560,48)

; [BRAND] Label "Powered by Think-C" di sidebar kiri bawah — seperti ESET
GUICtrlCreateLabel("Powered by Think-C", 0, 565, 178, 20, $SS_CENTER)
GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")  ;
GUICtrlSetColor(-1, 0x475569)               ; slate-500, visible di dark bg
GUICtrlSetBkColor(-1, $COLOR_SIDEBAR)       ; match sidebar background

; ===== CONTENT AREA =====
Global $pOverview = GUICreate("",720,$GUI_H-$HEADER_H, 180, $HEADER_H, BitOR($WS_CHILD,$WS_CLIPSIBLINGS), -1, $hGUI)
GUISwitch($pOverview)
GUISetBkColor($COLOR_BG)

; ========== BANNER OVERVIEW ==========
Global $idBannerOverview = GUICtrlCreateLabel("",0,0,720,60)
GUICtrlSetBkColor(-1,$COLOR_BG)

Global $idBannerTitleOverview = GUICtrlCreateLabel("Overview",20,15,300,25)
GUICtrlSetColor(-1,0xFFFFFF)
GUICtrlSetFont(-1,14,700,0,"Segoe UI")

Global $idBannerSubOverview = GUICtrlCreateLabel("System protection status and rule statistics",20,40,500,20)
GUICtrlSetColor(-1,0x8B949E)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")

; ========== CARD LAYOUT AUTO CENTER ==========
Local $contentX = 0
Local $contentW = 720

Local $cardW = 620
Local $cardX = $contentX + Int(($contentW - $cardW) / 2)

Local $cardY1 = 70
Local $cardY2 = 215  ; gap seragam 5px dari bawah card1 (70+155+5)
Local $cardY3 = 340  ; gap seragam 5px dari bawah card2 (230+115+5)
Local $textX  = $cardX + 20

; ========== PROTECTION STATUS ==========
$idCard1 = GUICtrlCreateLabel("", $cardX, $cardY1, $cardW, 135)
GUICtrlSetBkColor(-1,$COLOR_CARD)

GUICtrlCreateIcon("shell32.dll",44,$textX-20,$cardY1+10,16,16)
$idCard1Title = GUICtrlCreateLabel("✔ Protected Status", $textX, $cardY1 + 10, 575, 25, _
    BitOR($SS_NOTIFY, $SS_CENTERIMAGE))  ; SS_NOTIFY = clickable untuk update banner
GUICtrlSetColor(-1, 0x8CE99A)
GUICtrlSetFont(-1, 12, 800, 0, "Segoe UI")
GUICtrlCreateLabel("",$textX,$cardY1 + 35,575,1)
GUICtrlSetBkColor(-1,0x334155)

$idCard1Text = GUICtrlCreateLabel("", $textX, $cardY1 + 40, 575, 85)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetFont(-1, 11, 400, 0, "Segoe UI")

; ========== DATABASE STATUS ==========
$idCard2 = GUICtrlCreateLabel("", $cardX, $cardY2, $cardW, 115)
GUICtrlSetBkColor(-1,$COLOR_CARD)

GUICtrlCreateIcon("shell32.dll",23,$textX-20,$cardY2+10,16,16)
$idCard2Title = GUICtrlCreateLabel("✔ Rules Statistik", $textX, $cardY2 + 10, 575, 25)
GUICtrlSetColor(-1, 0x6EA8FE)
GUICtrlSetFont(-1, 12, 800, 0, "Segoe UI")
GUICtrlCreateLabel("",$textX,$cardY2 + 35,575,1)
GUICtrlSetBkColor(-1,0x334155)

$idCard2Text = GUICtrlCreateLabel("", $textX, $cardY2 + 40, 575, 65)
GUICtrlSetColor(-1, 0xFFFFFF)
GUICtrlSetFont(-1, 11, 400, 0, "Segoe UI")

; ========== THREAT ACTIVITY ==========
$idCard3 = GUICtrlCreateLabel("", $cardX, $cardY3, $cardW, 150)
GUICtrlSetBkColor(-1,$COLOR_CARD)

GUICtrlCreateIcon("shell32.dll",47,$textX-20,$cardY3+10,16,16)
$idCard3Title = GUICtrlCreateLabel("✔ Threat Activity", $textX, $cardY3 + 10, 575, 25)
GUICtrlSetColor(-1,0xFACC15)
GUICtrlSetFont(-1,12,800,0,"Segoe UI")
GUICtrlCreateLabel("",$textX,$cardY3 + 35,575,1)
GUICtrlSetBkColor(-1,0x334155)

$idCard3Text = GUICtrlCreateLabel("", $textX, $cardY3 + 40, 575, 100)

GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,11,400,0,"Segoe UI")

; ==========PANEL ANALYTICS==========
Global $pAnalytics = GUICreate("",720,$GUI_H-$HEADER_H,180,$HEADER_H, BitOR($WS_CHILD,$WS_CLIPSIBLINGS), -1, $hGUI)
GUISwitch($pAnalytics)
GUISetBkColor($COLOR_BG)

GUICtrlCreateLabel("",0,0,720,60)
GUICtrlSetBkColor(-1,$COLOR_BG)
GUICtrlCreateLabel("Analytics",20,18,300,25)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,14,700,0,"Segoe UI")

; --- ROW 1 (y=86..276) ---
; Kolom kiri: Attack Timeline
GUICtrlCreateLabel("Attack Timeline",18,66,200,18)
GUICtrlSetColor(-1,0x60A5FA)
GUICtrlSetFont(-1,9,700,0,"Segoe UI")
GUICtrlSetBkColor(-1,-2)
$idAnalyticTimeline = GUICtrlCreateListView("Time|Process|Action|Threat",18,86,338,190)
GUICtrlSetFont(-1,9,400,0,"Segoe UI")
_GUICtrlListView_SetColumnWidth($idAnalyticTimeline,0,72)
_GUICtrlListView_SetColumnWidth($idAnalyticTimeline,1,90)
_GUICtrlListView_SetColumnWidth($idAnalyticTimeline,2,80)
_GUICtrlListView_SetColumnWidth($idAnalyticTimeline,3,70)

; Kolom kanan: Top Suspicious Process
GUICtrlCreateLabel("Top Suspicious Process",364,66,250,18)
GUICtrlSetColor(-1,0xFACC15)
GUICtrlSetFont(-1,9,700,0,"Segoe UI")
GUICtrlSetBkColor(-1,-2)
$idAnalyticTopProc = GUICtrlCreateListView("Process|Score|Hits",364,86,338,190)
GUICtrlSetFont(-1,9,400,0,"Segoe UI")
_GUICtrlListView_SetColumnWidth($idAnalyticTopProc,0,145)
_GUICtrlListView_SetColumnWidth($idAnalyticTopProc,1,80)
_GUICtrlListView_SetColumnWidth($idAnalyticTopProc,2,80)

; --- ROW 2 (y=306..496) ---
; Kolom kiri: Ransomware Activity
GUICtrlCreateLabel("Ransomware Activity",18,284,250,18)
GUICtrlSetColor(-1,0xF87171)
GUICtrlSetFont(-1,9,700,0,"Segoe UI")
GUICtrlSetBkColor(-1,-2)
$idAnalyticRansom = GUICtrlCreateListView("Family|Hits|Level",18,306,338,190)
GUICtrlSetFont(-1,9,400,0,"Segoe UI")
_GUICtrlListView_SetColumnWidth($idAnalyticRansom,0,145)
_GUICtrlListView_SetColumnWidth($idAnalyticRansom,1,80)
_GUICtrlListView_SetColumnWidth($idAnalyticRansom,2,85)

; Kolom kanan: Attack Graph (chain summary)
GUICtrlCreateLabel("Attack Graph",364,284,250,18)
GUICtrlSetColor(-1,0xA78BFA)
GUICtrlSetFont(-1,9,700,0,"Segoe UI")
GUICtrlSetBkColor(-1,-2)
$idAnalyticGraph = GUICtrlCreateListView("Chain|Count",364,306,338,190)
GUICtrlSetFont(-1,9,400,0,"Segoe UI")
_GUICtrlListView_SetColumnWidth($idAnalyticGraph,0,215)
_GUICtrlListView_SetColumnWidth($idAnalyticGraph,1,95)

; ==========PANEL MODULES (gabungan Protection + Detection)==========
Global $pModules = GUICreate("",720,$GUI_H-$HEADER_H,180,$HEADER_H, BitOR($WS_CHILD,$WS_CLIPSIBLINGS), -1, $hGUI)
; Alias untuk kompatibilitas
Global $pProtection = $pModules
Global $pDetection  = $pModules
GUISwitch($pModules)
GUISetBkColor($COLOR_BG)

GUICtrlCreateLabel("",0,0,720,60)
GUICtrlSetBkColor(-1,$COLOR_BG)

GUICtrlCreateLabel("Modules",20,18,300,25)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,13,700,0,"Segoe UI")

; Kolom kiri (col 1): row 0-8
Global $swAdaptive    = _SwitchModule2("Adaptive AI",           1, 0, $MOD_ADAPTIVE_AI)
Global $swAdaptiveScan= _SwitchModule2("Adaptive Scan Rate",    1, 1, $MOD_ADAPTIVE_SCAN)
Global $swChain       = _SwitchModule2("Attack Chain",          1, 2, $MOD_ATTACK_CHAIN)
Global $swBehavior    = _SwitchModule2("Behavior Engine",       1, 3, $MOD_BEHAVIOR_ENGINE)
Global $swBeaconAdv   = _SwitchModule2("C2 Beacon + DGA",       1, 4, $MOD_BEACON_ADV)
Global $swCredDump    = _SwitchModule2("Credential Dump",       1, 5, $MOD_CRED_DUMP)
Global $swFileless    = _SwitchModule2("Fileless Detection",    1, 6, $MOD_FILELESS_DETECT)
Global $swLolbin      = _SwitchModule2("LOLBins Detection",     1, 7, $MOD_LOLBIN_DETECT)
Global $swLateral     = _SwitchModule2("Lateral Movement",      1, 8, $MOD_LATERAL)

; Kolom kanan (col 2): row 0-8
Global $swMass        = _SwitchModule2("Mass Encryption",       2, 0, $MOD_MASS_PROTECT)
Global $swMemory      = _SwitchModule2("Memory Injection",      2, 1, $MOD_MEMORY_INJECT)
Global $swNet         = _SwitchModule2("Network C2",            2, 2, $MOD_NET_BLOCK)
Global $swPSChain     = _SwitchModule2("PowerShell Chain",      2, 3, $MOD_PS_CHAIN)
Global $swRansom      = _SwitchModule2("Ransomware Behavior",   2, 4, $MOD_RANSOM_BEHAVIOR)
Global $swHoney       = _SwitchModule2("Ransomware Honeypot",   2, 5, $MOD_RANSOM_HONEYPOT)
Global $swSelfDef     = _SwitchModule2("Self Defense",          2, 6, $MOD_SELF_DEFENSE)
Global $swThreatIntel = _SwitchModule2("Threat Intel (URLhaus)",2, 7, $MOD_THREAT_INTEL)
Global $swEventLog    = _SwitchModule2("Windows Event Log",     2, 8, $MOD_EVENT_LOG)

; Tombol Enable All dan Disable All — di bawah row 8 (y=502)
Global $btnEnableAll  = GUICtrlCreateButton("Enable All",  15,  467, 150, 30)
Global $btnDisableAll = GUICtrlCreateButton("Disable All", 175, 467, 150, 30)
GUICtrlSetFont($btnEnableAll,  9, 600, 0, "Segoe UI")
GUICtrlSetFont($btnDisableAll, 9, 600, 0, "Segoe UI")

; ==========PANEL RULES==========
Global $pRules = GUICreate("",720,$GUI_H-$HEADER_H, 180, $HEADER_H, _
    BitOR($WS_CHILD,$WS_CLIPSIBLINGS), -1, $hGUI)
GUISwitch($pRules)
GUISetBkColor($COLOR_BG)

GUICtrlCreateLabel("",0,0,720,60)
GUICtrlSetBkColor(-1,$COLOR_BG)

GUICtrlCreateLabel("Rules",20,18,200,25)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,14,700,0,"Segoe UI")

Global $btnRuleApps = _ToolNavBtn("Apps",40)
Global $btnRuleRans = _ToolNavBtn("Ransomware",200)
Global $btnRuleNet  = _ToolNavBtn("Network",360)

$idListApps = GUICtrlCreateListView("Category|ListCount|HitCount",30,110,640,340)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")

$idListRans = GUICtrlCreateListView("Family|Level|HashCount|HitCount",30,110,640,340)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")
GUICtrlSetState(-1,$GUI_HIDE)

$idListNet = GUICtrlCreateListView("Category|ListCount|HitCount",30,110,640,340)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")
GUICtrlSetState(-1,$GUI_HIDE)

; ==========PANEL TOOLS==========
Global $pTools = GUICreate("",720,$GUI_H-$HEADER_H, 180, $HEADER_H, _
    BitOR($WS_CHILD, $WS_CLIPSIBLINGS), -1, $hGUI)
GUISwitch($pTools)
GUISetBkColor($COLOR_BG)

Global $idBannerTools = GUICtrlCreateLabel("",0,0,720,60)
GUICtrlSetBkColor(-1,$COLOR_BG)

GUICtrlCreateLabel("Tools",20,18,200,25)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,14,700,0,"Segoe UI")

Global $btnToolQuar  = _ToolNavBtn("Quarantine", 40)
Global $btnToolWhite = _ToolNavBtn("Whitelist", 200)
Global $btnToolLogs  = _ToolNavBtn("Logs", 360)
Global $btnWhiteAddFile   = GUICtrlCreateButton("Add File",   195, 420, 120, 30)
$btnWhiteAddFolder = GUICtrlCreateButton("Add Folder", 325, 420, 120, 30)
GUICtrlSetState($btnWhiteAddFile,$GUI_HIDE)
GUICtrlSetState($btnWhiteAddFolder,$GUI_HIDE)
Global $btnLogExport   = GUICtrlCreateButton("Export Log",30,460,120,30)
GUICtrlSetState($btnLogExport,$GUI_HIDE)
$btnExportCSV = GUICtrlCreateButton("Export CSV",165,460,130,30)
GUICtrlSetFont($btnExportCSV, 9, 600, 0, "Segoe UI")
GUICtrlSetState($btnExportCSV,$GUI_HIDE)

$idListToolQuar = GUICtrlCreateListView("Time|File|Reason",30,110,640,300)
GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
_GUICtrlListView_SetExtendedListViewStyle($idListToolQuar, BitOR(0x20, 0x4)) ; FULLROWSELECT + CHECKBOXES

; Tombol aksi Quarantine — multi-select via checkbox listview
Global $btnQuarRestore  = GUICtrlCreateButton("Restore to Origin", 30, 420, 150, 28)
Global $btnQuarDelete   = GUICtrlCreateButton("Delete Permanent",  195, 420, 150, 28)
$btnQuarWhitelist = GUICtrlCreateButton("Add to Whitelist", 360, 420, 150, 28)
GUICtrlSetFont($btnQuarRestore,   9, 600, 0, "Segoe UI")
GUICtrlSetFont($btnQuarDelete,    9, 600, 0, "Segoe UI")
GUICtrlSetFont($btnQuarWhitelist, 9, 600, 0, "Segoe UI")
GUICtrlSetState($btnQuarRestore,   $GUI_HIDE)
GUICtrlSetState($btnQuarDelete,    $GUI_HIDE)
GUICtrlSetState($btnQuarWhitelist, $GUI_HIDE)

$idListToolWhite = GUICtrlCreateListView("Path|Hash",30,110,640,300)
GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
_GUICtrlListView_SetExtendedListViewStyle($idListToolWhite, BitOR(0x20, 0x4)) ; FULLROWSELECT + CHECKBOXES
GUICtrlSetState(-1,$GUI_HIDE)

; Tombol aksi Whitelist — remove via checkbox
$btnWhiteRemove = GUICtrlCreateButton("Remove Selected", 30, 420, 150, 28)
GUICtrlSetFont($btnWhiteRemove, 9, 600, 0, "Segoe UI")
GUICtrlSetState($btnWhiteRemove, $GUI_HIDE)

$idListToolLog = GUICtrlCreateListView("Time|Process|Reason",30,110,640,310)
GUICtrlSetFont(-1, 10, 400, 0, "Segoe UI")
GUICtrlSetState(-1,$GUI_HIDE)

; Rollback tab controls (dalam pTools)
Global $btnToolRollback = _ToolNavBtn("Rollback", 520)

; ListView: tab Protected Folders (kiri) dan Backup Files (kanan)
$idListRollbackFolders = GUICtrlCreateListView("Protected Folder|Files",30,122,300,210)
GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
GUICtrlSetState(-1, $GUI_HIDE)

$idListToolRollback = GUICtrlCreateListView("Backup File|Original Path|Size|Date",340,122,310,210)
GUICtrlSetFont(-1, 9, 400, 0, "Segoe UI")
_GUICtrlListView_SetExtendedListViewStyle($idListToolRollback, BitOR(0x20, 0x4)) ; FULLROWSELECT + CHECKBOXES
GUICtrlSetState(-1, $GUI_HIDE)

; Tombol kiri: manage protected folders
Global $btnRollbackAddFolder  = GUICtrlCreateButton("+ Add Folder", 30,  342, 120, 28)
Global $btnRollbackAddFile    = GUICtrlCreateButton("+ Add File",   158, 342, 100, 28)
Global $btnRollbackRemFolder  = GUICtrlCreateButton("Remove",       266, 342,  80, 28)
GUICtrlSetFont($btnRollbackAddFolder, 9, 600, 0, "Segoe UI")
GUICtrlSetFont($btnRollbackAddFile,   9, 600, 0, "Segoe UI")
GUICtrlSetFont($btnRollbackRemFolder, 9, 600, 0, "Segoe UI")
GUICtrlSetState($btnRollbackAddFolder, $GUI_HIDE)
GUICtrlSetState($btnRollbackAddFile,   $GUI_HIDE)
GUICtrlSetState($btnRollbackRemFolder, $GUI_HIDE)

; Tombol kanan: restore backup
Global $btnRollbackRestore    = GUICtrlCreateButton("Restore to Origin", 340, 342, 148, 28)
Global $btnRollbackToDesktop  = GUICtrlCreateButton("Restore to Desktop", 496, 342, 148, 28)
GUICtrlSetFont($btnRollbackRestore,   9, 600, 0, "Segoe UI")
GUICtrlSetFont($btnRollbackToDesktop, 9, 600, 0, "Segoe UI")
GUICtrlSetState($btnRollbackRestore,   $GUI_HIDE)
GUICtrlSetState($btnRollbackToDesktop, $GUI_HIDE)

; Label section
$lblRollbackL = GUICtrlCreateLabel("Protected Folders", 30, 100, 200, 18)
GUICtrlSetColor($lblRollbackL, 0x60A5FA)
GUICtrlSetFont($lblRollbackL, 10, 700, 0, "Segoe UI")
GUICtrlSetBkColor($lblRollbackL, -2)
GUICtrlSetState($lblRollbackL, $GUI_HIDE)
$lblRollbackR = GUICtrlCreateLabel("Backed-up Files", 340, 100, 200, 18)
GUICtrlSetColor($lblRollbackR, 0x4ADE80)
GUICtrlSetFont($lblRollbackR, 10, 700, 0, "Segoe UI")
GUICtrlSetBkColor($lblRollbackR, -2)
GUICtrlSetState($lblRollbackR, $GUI_HIDE)

; Info bar
$lblRollbackInfo = GUICtrlCreateLabel("Auto-backup every " & $g_BackupIntervalMin & " min  |  Monitors your protected folders.", 30, 376, 620, 18)
GUICtrlSetColor($lblRollbackInfo, 0x64748B)
GUICtrlSetFont($lblRollbackInfo, 9, 400, 0, "Segoe UI")
GUICtrlSetBkColor($lblRollbackInfo, -2)
GUICtrlSetState($lblRollbackInfo, $GUI_HIDE)

; ==========PANEL SETTINGS==========
Global $pSettings = GUICreate("",720,$GUI_H-$HEADER_H,180,$HEADER_H, _
    BitOR($WS_CHILD,$WS_CLIPSIBLINGS), -1, $hGUI)
GUISwitch($pSettings)
GUISetBkColor($COLOR_BG)

GUICtrlCreateLabel("",0,0,720,60)
GUICtrlSetBkColor(-1,$COLOR_BG)
GUICtrlCreateLabel("Settings",20,18,300,25)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,14,700,0,"Segoe UI")

; --- Scan Interval ---
GUICtrlCreateLabel("Scan Interval (seconds)",30,80,300,20)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")
$sliderScanInterval = GUICtrlCreateSlider(30,106,400,24)
GUICtrlSetLimit($sliderScanInterval,30,3)
GUICtrlSetData($sliderScanInterval, Int($SCAN_INTERVAL / 1000))
$lblScanInterval = GUICtrlCreateLabel(Int($SCAN_INTERVAL/1000) & "s",440,106,60,24)
GUICtrlSetColor($lblScanInterval,$COLOR_SUBTEXT)

; --- Kill Cooldown ---
GUICtrlCreateLabel("Kill Cooldown (seconds)",30,148,300,20)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")
$sliderKillCooldown = GUICtrlCreateSlider(30,174,400,24)
GUICtrlSetLimit($sliderKillCooldown,60,5)
GUICtrlSetData($sliderKillCooldown, Int($KILL_COOLDOWN / 1000))
$lblKillCooldown = GUICtrlCreateLabel(Int($KILL_COOLDOWN/1000) & "s",440,174,60,24)
GUICtrlSetColor($lblKillCooldown,$COLOR_SUBTEXT)

; --- AI Block Score ---
GUICtrlCreateLabel("AI Block Threshold (score)",30,216,300,20)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")
$sliderAIBlock = GUICtrlCreateSlider(30,242,400,24)
GUICtrlSetLimit($sliderAIBlock,50,5)
GUICtrlSetData($sliderAIBlock,$AI_BLOCK_SCORE)
$lblAIBlock = GUICtrlCreateLabel($AI_BLOCK_SCORE,440,242,60,24)
GUICtrlSetColor($lblAIBlock,$COLOR_SUBTEXT)

; --- Backup Disk Quota ---
GUICtrlCreateLabel("Backup Disk Quota (MB)",30,284,300,20)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")
$sliderBackupQuota = GUICtrlCreateSlider(30,308,400,24)
GUICtrlSetLimit($sliderBackupQuota, 5120, 500)
GUICtrlSetData($sliderBackupQuota, $g_BackupQuotaMB)
$lblBackupQuota = GUICtrlCreateLabel(_FormatQuotaLabel($g_BackupQuotaMB), 440,308,120,24)
GUICtrlSetColor($lblBackupQuota,$COLOR_SUBTEXT)
GUICtrlSetFont($lblBackupQuota,9,400,0,"Segoe UI")

; --- Backup Interval ---
GUICtrlCreateLabel("Backup Interval (minutes)",30,350,300,20)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,10,400,0,"Segoe UI")
$sliderBackupInterval = GUICtrlCreateSlider(30,374,400,24)
GUICtrlSetLimit($sliderBackupInterval, 30, 2)
GUICtrlSetData($sliderBackupInterval, $g_BackupIntervalMin)
$lblBackupInterval = GUICtrlCreateLabel($g_BackupIntervalMin & " min", 440,374,80,24)
GUICtrlSetColor($lblBackupInterval,$COLOR_SUBTEXT)
GUICtrlSetFont($lblBackupInterval,9,400,0,"Segoe UI")

; --- Tombol ---
Global $btnSettingsSave  = GUICtrlCreateButton("Save Settings",30,418,160,34)
Global $btnSettingsReset = GUICtrlCreateButton("Reset Default",210,418,160,34)

; hint text
GUICtrlCreateLabel("Changes take effect after Save. Restart not required.",30,464,500,20)
GUICtrlSetColor(-1,$COLOR_SUBTEXT)
GUICtrlSetFont(-1,9,400,0,"Segoe UI")

; ==========PANEL INTEGRATION==========
Global $pIntegration = GUICreate("",720,$GUI_H-$HEADER_H,180,$HEADER_H, _
BitOR($WS_CHILD,$WS_CLIPSIBLINGS), -1, $hGUI)

GUISwitch($pIntegration)
GUISetBkColor($COLOR_BG)

GUICtrlCreateLabel("",0,0,720,60)
GUICtrlSetBkColor(-1,$COLOR_BG)
GUICtrlCreateLabel("Integration",20,18,300,25)
GUICtrlSetColor(-1,$COLOR_TEXT)
GUICtrlSetFont(-1,14,700,0,"Segoe UI")

; --- SIEM (toggle → popup config) ---
Global $btnWazuh = _SwitchModule("SIEM Integration (Wazuh)",60,$SIEM_ACTIVE)

; --- Patriot Server (toggle → popup config, sama seperti SIEM) ---
Global $btnPatriotServer = _SwitchModule("Patriot Server",120,$g_PatriotConnected)

; Stub vars (dibutuhkan oleh _SaveIntegrationConfig / _LoadConfig) ---
Global $inpNetPath = 0, $inpNetUser = 0, $inpNetPass = 0, $btnNetTest = 0
Global $inpWebDAV  = 0, $inpWebUser = 0, $inpWebPass = 0, $btnWebTest = 0
Global $inpPatriotIP     = 0
Global $inpPatriotPort   = 0
Global $inpPatriotEndpID = 0
Global $lblPatriotStatus = 0
Global $btnPatriotGetKey  = 0
Global $btnPatriotSrvTest = 0
Global $btnPatriotDisconn = 0
Global $btnIntegrationSave = 0

; ========================================
GUISwitch($hGUI) ; balik ke main GUI

GUICtrlCreateGroup("",-99,-99,1,1)
Global $btnOverview   = _SideBtn("Overview",   15 + $HEADER_H, 44)
Global $btnAnalytics  = _SideBtn("Analytics",  65 + $HEADER_H, 22)
Global $btnModules    = _SideBtn("Modules",    115 + $HEADER_H, 20)
Global $btnRules      = _SideBtn("Rules",      165 + $HEADER_H, 147)
Global $btnTools      = _SideBtn("Tools",      215 + $HEADER_H, 20)
Global $btnIntegration = _SideBtn("Integration",265 + $HEADER_H, 13)
Global $btnSettings   = _SideBtn("Settings",   315 + $HEADER_H, 165)
; Alias untuk kompatibilitas
Global $btnProtection = $btnModules
Global $btnDetection  = $btnModules

; [STARTUP-HIDE] GUI disembunyikan saat startup.
GUISetState(@SW_HIDE, $hGUI)

_ApplyRoundedCorners($hGUI, 15)

; Sembunyikan semua panel dulu saat startup
GUISetState(@SW_HIDE, $pOverview)
GUISetState(@SW_HIDE, $pProtection)
GUISetState(@SW_HIDE, $pDetection)
GUISetState(@SW_HIDE, $pRules)
GUISetState(@SW_HIDE, $pTools)
GUISetState(@SW_HIDE, $pIntegration)
GUISetState(@SW_HIDE, $pSettings)

WinActivate($hGUI)

AdlibRegister("_StartupInit", 100)

; ========== TRAY INIT ==========
Opt("TrayMenuMode", 3)
Opt("TrayOnEventMode", 1)

TraySetToolTip($TRAY_TOOLTIP)
TraySetIcon(@ScriptDir & "\patriot.ico")

Global $trayOpen  = TrayCreateItem("Open Dashboard")
TrayCreateItem("")
Global $trayExit  = TrayCreateItem("Exit")

TrayItemSetOnEvent($trayOpen, "_TrayOpen")
TrayItemSetOnEvent($trayExit, "_TrayExit")

TraySetClick(16) ; double-click
TraySetOnEvent($TRAY_EVENT_PRIMARYDOUBLE, "_TrayOpen")

TraySetState()

GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")

If $AUTO_START_SHIELD Then
    $bIsBlocking = True
    TraySetToolTip("UltraBlocker Shield ON")
    ; Spawn guardian hanya jika belum ada
    Local $g2path = @ProgramFilesDir & "\Patriot Ultra Blocker\ultrablocker.exe"
    If Not FileExists($g2path) Then $g2path = @ScriptDir & "\ultrablocker.exe"

    ; Guardian1 — patriot.exe /guardian
    If Not ProcessExists("patriot.exe /guardian") Then
        Run(@ScriptFullPath & " /guardian", "", @SW_HIDE)
        Sleep(500)
    EndIf

    ; Guardian2 — ultrablocker.exe
    If Not ProcessExists("ultrablocker.exe") Then
        If FileExists($g2path) Then
            Run('"' & $g2path & '"', "", @SW_HIDE)
        Else
            Run(@ScriptFullPath & " /guardian2", "", @SW_HIDE)
        EndIf
    EndIf
    _UpdateOverview()
EndIf

GUIRegisterMsg($WM_DROPFILES, "_OnDrop")

GUIRegisterMsg($WM_NCHITTEST, "_HitTest")

; ========== MAIN LOOP ==========
While 1

    Local $msg = GUIGetMsg()

    Switch $msg

        ; ========== MAIN NAV ==========
        Case $btnOverview
            _HighlightBtn($btnOverview)
            _ShowPanel($pOverview)

        Case $btnAnalytics
            _HighlightBtn($btnAnalytics)
            _ShowPanel($pAnalytics)
            _UpdateAnalytics()

        Case $btnModules
            _HighlightBtn($btnModules)
            _ShowPanel($pModules)

	Case $btnRules
    	    _HighlightBtn($btnRules)
    	    _ShowPanel($pRules)
    	    _SwitchRulesPanel(1)

        Case $btnTools
            _HighlightBtn($btnTools)
            _ShowPanel($pTools)
            _SwitchToolsPanel(1)

	Case $btnIntegration
    	    _HighlightBtn($btnIntegration)
    	    _ShowPanel($pIntegration)

	Case $btnSettings
	    _HighlightBtn($btnSettings)
	    _ShowPanel($pSettings)

        Case $btnEnableAll
            _SetAllModules(True)

        Case $btnDisableAll
            _SetAllModules(False)

	Case $sliderScanInterval
	    GUICtrlSetData($lblScanInterval, GUICtrlRead($sliderScanInterval) & "s")

	Case $sliderKillCooldown
	    GUICtrlSetData($lblKillCooldown, GUICtrlRead($sliderKillCooldown) & "s")

	Case $sliderAIBlock
	    GUICtrlSetData($lblAIBlock, GUICtrlRead($sliderAIBlock))

        Case $sliderBackupQuota
            Local $qv = GUICtrlRead($sliderBackupQuota)
            GUICtrlSetData($lblBackupQuota, _FormatQuotaLabel($qv))

        Case $sliderBackupInterval
            GUICtrlSetData($lblBackupInterval, GUICtrlRead($sliderBackupInterval) & " min")

	Case $btnSettingsSave
	    _SaveSettings()

	Case $btnSettingsReset
	    _ResetSettingsDefault()

	Case $btnWazuh
    	    If Not $SIEM_ACTIVE Then
        	If _SIEM_Config() Then

            	    $SIEM_ACTIVE = True
            	    GUICtrlSetData($btnWazuh,"ON")
            	    GUICtrlSetBkColor($btnWazuh,$COLOR_SUCCESS)

        	EndIf
    	    Else
        	Local $res = _PasswordDialog("Disable SIEM Integration")
        	Local $p = $res[0]

        	; [HIGH-1 FIX] Gunakan _VerifyPassword (support v2 salted + legacy)
        	If _VerifyPassword($p, $EXIT_PASSWORD_HASH) Then

            	    $SIEM_ACTIVE = False
            	    IniDelete($CONFIG_FILE,"siem")

            	    GUICtrlSetData($btnWazuh,"OFF")
            	    GUICtrlSetBkColor($btnWazuh,0x374151)

        	EndIf
    	    EndIf

	Case $btnPatriotServer
    	    If Not $g_PatriotConnected Then
    	        If _PatriotSrv_Config() Then
    	            GUICtrlSetData($btnPatriotServer, "ON")
    	            GUICtrlSetBkColor($btnPatriotServer, $COLOR_SUCCESS)
    	        EndIf
    	    Else
    	        Local $res = _PasswordDialog("Disconnect Patriot Server")
    	        ; [HIGH-1 FIX] Gunakan _VerifyPassword (support v2 salted + legacy)
    	        If _VerifyPassword($res[0], $EXIT_PASSWORD_HASH) Then
    	            _PatriotSrvDisconnect()
    	            GUICtrlSetData($btnPatriotServer, "OFF")
    	            GUICtrlSetBkColor($btnPatriotServer, 0x374151)
    	        EndIf
    	    EndIf

        ; ========== TOOLS PANEL ==========
        Case $btnToolQuar
            _SwitchToolsPanel(1)

        Case $btnToolWhite
            _SwitchToolsPanel(2)

        Case $btnToolLogs
            _SwitchToolsPanel(3)

	Case $btnLogExport
	    _ExportDailyLog()

	Case $btnExportCSV
	    _ExportThreatCSV()

	; ===== QUARANTINE ACTIONS (multi-select) =====
	Case $btnQuarRestore
	    _QuarActionMulti("restore")

	Case $btnQuarDelete
	    _QuarActionMulti("delete")

	Case $btnQuarWhitelist
	    _QuarActionMulti("whitelist")

	; ===== WHITELIST REMOVE (multi-select) =====
	Case $btnWhiteRemove
	    _WhiteRemoveMulti()

	Case $btnToolRollback
	    _SwitchToolsPanel(4)

	Case $btnRollbackRestore
	    _RestoreRollbackFile(False)  ; restore ke path asli

	Case $btnRollbackToDesktop
	    _RestoreRollbackFile(True)   ; restore ke Desktop

	Case $btnRollbackAddFolder
	    _AddRollbackFolder(False)

	Case $btnRollbackAddFile
	    _AddRollbackFolder(True)

	Case $btnWhiteAddFile
    	    _WhitelistAddFile()

	Case $btnWhiteAddFolder
    	    _WhitelistAddFolder()

	Case $btnRuleApps
   	    _SwitchRulesPanel(1)

	Case $btnRuleRans
    	    _SwitchRulesPanel(2)

	Case $btnRuleNet
    	    _SwitchRulesPanel(3)
    	    
        ; ========== TOGGLE MODULES ==========
        Case $swBehavior
            $MOD_BEHAVIOR_ENGINE = _ToggleModule($swBehavior)

    	Case $swChain
    	    $MOD_ATTACK_CHAIN = _ToggleModule($swChain)

        Case $swLolbin
            $MOD_LOLBIN_DETECT = _ToggleModule($swLolbin)

        Case $swPSChain
            $MOD_PS_CHAIN = _ToggleModule($swPSChain)

        Case $swRansom
            $MOD_RANSOM_BEHAVIOR = _ToggleModule($swRansom)

	Case $swMass
    	    $MOD_MASS_PROTECT = _ToggleModule($swMass)

        Case $swNet
            $MOD_NET_BLOCK = _ToggleModule($swNet)

	Case $swAdaptive
    	    $MOD_ADAPTIVE_AI = _ToggleModule($swAdaptive)

	Case $swHoney
    	    $MOD_RANSOM_HONEYPOT = _ToggleModule($swHoney)

	Case $swFileless
	    $MOD_FILELESS_DETECT = _ToggleModule($swFileless)

	Case $swMemory
    	    $MOD_MEMORY_INJECT = _ToggleModule($swMemory)

	Case $swSelfDef
    	    $MOD_SELF_DEFENSE = _ToggleModule($swSelfDef)

	Case $swThreatIntel
    	    $MOD_THREAT_INTEL  = _ToggleModule($swThreatIntel)

	Case $swEventLog
    	    $MOD_EVENT_LOG     = _ToggleModule($swEventLog)

	Case $swAdaptiveScan
    	    $MOD_ADAPTIVE_SCAN = _ToggleModule($swAdaptiveScan)

	Case $swCredDump
    	    $MOD_CRED_DUMP = _ToggleModule($swCredDump)

	Case $swLateral
    	    $MOD_LATERAL   = _ToggleModule($swLateral)

	Case $swBeaconAdv
    	    $MOD_BEACON_ADV = _ToggleModule($swBeaconAdv)

        ; ========== HEADER ==========
        Case $btnMin
    	    _MinimizeToTray()

        Case $btnClose
    	    _MinimizeToTray()

        Case $lblUpdate
            ; Jika ada update app tersedia, tawarkan update dulu
            If $g_PendingAppVersion <> "" And $CLOUD_APP_INSTALLER <> "" Then
                _PromptAppUpdate()
            Else
                _SyncPopup()
            EndIf

        Case $lblPwd
            _ChangeExitPassword()

        Case $idCard1Title
            ; Klik card title saat ada update tersedia → prompt install
            If $g_PendingAppVersion <> "" Then
                _PromptAppUpdate()
            EndIf

        Case $GUI_EVENT_CLOSE
            Exit

    EndSwitch

    Sleep(10) ; batasi ~100 iter/detik, cegah CPU spike

WEnd

; [B-05 FIX] Tulis PID main GUI ke file sentinel.
Func _WritePIDSentinel()
    If Not FileExists($BASE_DIR) Then DirCreate($BASE_DIR)
    Local $h = FileOpen($SENTINEL_FILE, 2)
    If $h <> -1 Then
        FileWrite($h, String($PATRIOT_PID))
        FileClose($h)
    EndIf
EndFunc

; ========== CLEANUP ==========
Func _FirstBackup()
    AdlibUnRegister("_FirstBackup")
    _BackupRollbackFolders()
EndFunc

Func _Cleanup()

    ; Simpan data ML dan baseline sebelum exit agar tidak hilang
    _SaveTrustModel()
    _SaveBaseline()
    _SaveHashCache() ; [LOW-1 FIX] persist hash cache untuk sesi berikutnya

    ; Restore file permissions agar bisa dijalankan lagi
    FileSetAttrib(@ScriptFullPath, "-R")
    RunWait(@ComSpec & ' /c icacls "' & @ScriptFullPath & '" /reset', "", @SW_HIDE)

    ; [B-05 FIX] Hapus sentinel file saat exit normal.
    If FileExists($SENTINEL_FILE) Then FileDelete($SENTINEL_FILE)

    ; Tutup Event Log handle jika pernah dibuka
    _CloseEventLog()

    ; Shutdown Winsock jika SIEM socket pernah diinisialisasi
    If $SIEM_SOCKET And $SIEM_ACTIVE Then
        TCPShutdown()
    EndIf

    _Crypt_Shutdown()

EndFunc
