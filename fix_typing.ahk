#Requires AutoHotkey v2.0
#SingleInstance Force

; FixTyping.ahk
; Fixes text typed in the wrong layout (English <-> Arabic)
; Usage: Select text, Press F1
; Author: Antigravity

; ==============================================================================
; INITIALIZATION & SETTINGS
; ==============================================================================
TraySetIcon("shell32.dll", 45)
A_IconTip := "Fix Typing (F1)`nDouble-click to open Settings"

; Default Mappings (Arabic 101 / Libya)
; FIXED: Using the single char ligature "ﻻ" for the 'b' key preventing index shift
; The 'b' key is distinct from 'g' (ل) and 'h' (ا).
DefEn := '``-=qwertyuiop[]asdfghjkl;`'zxcvbnm,./~!@#$%^&*()_+QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?'
DefAr := "ذ-=ضصثقفغعهخحجدشسيبلاتنمكطئءؤرلاىةوزظ/ّ!@#$%^&*()_+ًٌَُلإإ‘÷×؛<>ٍ][لآأـ،/؟"

; We must patch DefAr to ensure 'b' position is a single char. 
; The sequence "لا" in the string above might be 2 chars.
; We replace the bottom row segment manually to be safe.
; Segment: "ئءؤرلاىةوزظ" -> "ئءؤر" . "ﻻ" . "ىةوزظ"
DefAr := StrReplace(DefAr, "رلاى", "ر" . Chr(0xFEFB) . "ى")

; Load Settings (Using MappingsV2 to force reset from buggy V1)
IniFile := A_ScriptDir "\settings.ini"
Mode := IniRead(IniFile, "Settings", "Mode", "Standard") ; Standard or Custom
EnMapStr := IniRead(IniFile, "MappingsV2", "En", DefEn)
ArMapStr := IniRead(IniFile, "MappingsV2", "Ar", DefAr)

; Global Maps
EnToAr := Map()
ArToEn := Map()
RebuildMaps(Mode, EnMapStr, ArMapStr)

; Tray Menu
A_TrayMenu.Delete()
A_TrayMenu.Add("Settings", ShowSettings)
A_TrayMenu.Add("Reload", ReloadApp)
A_TrayMenu.Add("Exit", ExitAppFunc)
A_TrayMenu.Default := "Settings"

ReloadApp(*) {
    Reload()
}
ExitAppFunc(*) {
    ExitApp()
}

; ==============================================================================
; HOTKEY
; ==============================================================================
F1::
{
    ; Backup Clipboard
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    
    Send "^c"
    if !ClipWait(0.5) {
        MsgBox("No text selected or copy failed.", "Error", 48)
        A_Clipboard := ClipSaved
        return
    }
    
    Text := A_Clipboard
    NewText := ""
    
    ; Detection Logic
    DetectedArabic := false
    Loop Parse, Text {
        if (Ord(A_LoopField) > 1000) 
        {
            DetectedArabic := true
            break
        }
    }
    
    ; Conversion
    if (Mode == "Standard") {
        ; STANDARD MODE
        if (DetectedArabic) {
            ; AR -> EN
            ; Handle both 2-char sequence and ligature for 'b'
            Text := StrReplace(Text, "لا", "b", , , 1)        ; lam + alif
            Text := StrReplace(Text, Chr(0xFEFB), "b", , , 1) ; ligature
            
            Loop Parse, Text {
                Char := A_LoopField
                if ArToEn.Has(Char)
                    NewText .= ArToEn[Char]
                else
                    NewText .= Char
            }
        } else {
            ; EN -> AR
            Loop Parse, Text {
                Char := A_LoopField
                if EnToAr.Has(Char)
                    NewText .= EnToAr[Char]
                else
                    NewText .= Char
            }
        }
    } else {
        ; CUSTOM MODE
        if (DetectedArabic) { 
            Loop Parse, Text {
                Char := A_LoopField
                if ArToEn.Has(Char) 
                    NewText .= ArToEn[Char]
                else if EnToAr.Has(Char) 
                    NewText .= EnToAr[Char]
                else
                    NewText .= Char 
            }
        } else {
            Loop Parse, Text {
                Char := A_LoopField
                if EnToAr.Has(Char)
                    NewText .= EnToAr[Char]
                else if ArToEn.Has(Char)
                    NewText .= ArToEn[Char]
                else
                    NewText .= Char
            }
        }
    }
    
    ; Paste
    A_Clipboard := NewText
    Send "^v"
    Sleep 100
    Send "{Alt down}{Shift}{Alt up}"
}

; ==============================================================================
; FUNCTIONS & GUI
; ==============================================================================
RebuildMaps(pMode, enStr, arStr) {
    global EnToAr, ArToEn
    EnToAr.Clear()
    ArToEn.Clear()
    
    if (pMode == "Standard") {
        strEn := DefEn
        strAr := DefAr
        
        Len := Min(StrLen(strEn), StrLen(strAr))
        Loop Len {
            cEn := SubStr(strEn, A_Index, 1)
            cAr := SubStr(strAr, A_Index, 1)
            EnToAr[cEn] := cAr
            ArToEn[cAr] := cEn
        }
        
    } else {
        ; CUSTOM MODE
        Len := Min(StrLen(enStr), StrLen(arStr))
        Loop Len {
            cEn := SubStr(enStr, A_Index, 1)
            cAr := SubStr(arStr, A_Index, 1)
            EnToAr[cEn] := cAr
            ArToEn[cAr] := cEn
        }
    }
}

ShowSettings(*) {
    MyGui := Gui(, "Fix Typing Settings")
    MyGui.SetFont("s10", "Segoe UI")
    
    MyGui.Add("Text", "w400 center", "--- Calibration Mode ---")
    
    ; Determine initial check states
    CheckStd := (Mode == "Standard") ? 1 : 0
    CheckCst := (Mode == "Custom") ? 1 : 0
    
    ; Radio Buttons
    RadStandard := MyGui.Add("Radio", "x50 vRadMode Checked" CheckStd, "Standard (Arabic 101)")
    RadCustom := MyGui.Add("Radio", "x+20 Checked" CheckCst, "Custom Layout")
    
    RadStandard.OnEvent("Click", (*) => ToggleInputs(false))
    RadCustom.OnEvent("Click", (*) => ToggleInputs(true))
    
    MyGui.Add("Text", "xm y+20", "English/Source:")
    
    RoOpt := (Mode == "Standard") ? "ReadOnly" : ""
    EditEn := MyGui.Add("Edit", "r3 w400 vEnStr " RoOpt, EnMapStr)
    
    MyGui.Add("Text",, "Target/Second:")
    EditAr := MyGui.Add("Edit", "r3 w400 vArStr " RoOpt, ArMapStr)
    
    BtnSave := MyGui.Add("Button", "Default w80 xm+160 y+20", "Save")
    BtnSave.OnEvent("Click", SaveSettings)
    
    ToggleInputs(enable) {
        if (enable) {
            EditEn.Opt("-ReadOnly")
            EditAr.Opt("-ReadOnly")
        } else {
            ; Reset text to default if switching to Standard
            EditEn.Value := DefEn
            EditAr.Value := DefAr
            EditEn.Opt("+ReadOnly")
            EditAr.Opt("+ReadOnly")
        }
    }
    
    MyGui.Show()
    
    SaveSettings(*) {
        SavedGui := MyGui.Submit()
        
        gMode := (SavedGui.RadMode == 1) ? "Standard" : "Custom"
        gEn := SavedGui.EnStr
        gAr := SavedGui.ArStr
        
        IniWrite(gMode, IniFile, "Settings", "Mode")
        ; Save to V2 section
        IniWrite(gEn, IniFile, "MappingsV2", "En")
        IniWrite(gAr, IniFile, "MappingsV2", "Ar")
        
        ; Update Global
        global Mode := gMode
        global EnMapStr := gEn
        global ArMapStr := gAr
        RebuildMaps(Mode, EnMapStr, ArMapStr)
        
        MsgBox("Settings Saved! Mode: " Mode, "Fix Typing", 64)
    }
}
