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
; We define the strings with standard 2-char sequences first, then patch them.
DefEn := '``-=qwertyuiop[]\asdfghjkl;`'zxcvbnm,./~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?'
DefAr := "ذ-=ضصثقفغعهخحجد\شسيبلاتنمكطئءؤرلاىةوزظّ!@#$%^&*()_+ًٌَُلإإ‘÷×؛<>|ٍ][لآأـ،/؟"

; PATCH: Convert 2-char Lam-Alifs to Single Unicode Ligatures to preserve alignment
; and prevent 'l' (Lam) from being overwritten by Uppercase mappings.

; 1. 'b' -> 'لا' (Lam + Alif) => Ligature U+FEFB
DefAr := StrReplace(DefAr, "رلاى", "ر" . Chr(0xFEFB) . "ى")

; 2. 'Shift+T' -> 'لإ' (Lam + Alif Hamza Below) => Ligature U+FEF9
DefAr := StrReplace(DefAr, "لإ", Chr(0xFEF9))

; 3. 'Shift+G' -> 'لآ' (Lam + Alif Madda) => Ligature U+FEF5
DefAr := StrReplace(DefAr, "لآ", Chr(0xFEF5))

; Load Settings (Using MappingsV5 to force reset)
IniFile := A_ScriptDir "\settings.ini"
Mode := IniRead(IniFile, "Settings", "Mode", "Standard")
EnMapStr := IniRead(IniFile, "MappingsV5", "En", DefEn)
ArMapStr := IniRead(IniFile, "MappingsV5", "Ar", DefAr)

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
; KEY INTERCEPTOR - Makes 'b' produce Ligature when Arabic is active
; ==============================================================================
#HotIf IsArabicActive()
$b::Send(Chr(0xFEFB)) ; Output Ligature instead of Lam+Alif
#HotIf

IsArabicActive() {
    ; Get current keyboard layout ID
    ; Arabic layouts typically have IDs starting with 0x0401 (Arabic Saudi), 0x1401 (Arabic Libya), etc.
    ThreadId := DllCall("GetWindowThreadProcessId", "Ptr", WinGetID("A"), "Ptr", 0)
    LayoutId := DllCall("GetKeyboardLayout", "UInt", ThreadId, "Ptr")
    LangId := LayoutId & 0xFFFF
    ; Arabic language IDs are in the 0x01-0x3F range for primary language = Arabic (0x01)
    return (LangId & 0x3F) == 0x01
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
            ; Pre-process: Ligature -> 'b' (from intercepted 'b' key)
            ; 2-char Lam+Alif (from 'gh') flows through normal mapping -> 'g' + 'h'
            Text := StrReplace(Text, Chr(0xFEFB), "b", , , 1) ; Ligature -> b
            
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
            
            ; Post-process: Convert 'gh' sequence (l + a) -> Ligature 
            ; BUT user said "make sure if person typed b or gh to get to لا".
            ; 'b' maps to Ligature (via EnToAr).
            ; 'gh' maps to 'l' 'a'. 
            ; The user output for 'gh' (Arabic) appears as 'لا' visually. 
            ; If we force 'l'+'a' -> Ligature, it becomes 'b' when flipped back.
            ; User asked to keep them separate? No, "make sure... to get to لا".
            ; Wait, if they look same, they are same?
            ; If I convert 'l'+'a' -> Ligature, then F1 will turn it to 'b'.
            ; If I DON'T convert, F1 turns it to 'gh'.
            ; Step 321 user said "not fixed" (meaning they don't want b?).
            
            ; Correct behavior:
            ; Input 'gh' -> 'l' + 'a'. Visual: 'لا'.
            ; Flip back -> 'g' + 'h'.
            ; Input 'b' -> Ligature. Visual: 'لا'.
            ; Flip back -> 'b'.
            
            ; So: We do NOT force merge 'l'+'a' to Ligature.
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

+F1::ShowSettings()

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
        
        ; Force Symbols to map to themselves
        SafeChars := "!@#$%^&*()_+"
        Loop Parse, SafeChars {
            EnToAr[A_LoopField] := A_LoopField
            ArToEn[A_LoopField] := A_LoopField
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
    
    CheckStd := (Mode == "Standard") ? 1 : 0
    CheckCst := (Mode == "Custom") ? 1 : 0
    
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
        IniWrite(gEn, IniFile, "MappingsV5", "En")
        IniWrite(gAr, IniFile, "MappingsV5", "Ar")
        
        global Mode := gMode
        global EnMapStr := gEn
        global ArMapStr := gAr
        RebuildMaps(Mode, EnMapStr, ArMapStr)
        
        MsgBox("Settings Saved! Mode: " Mode, "Fix Typing", 64)
    }
}
