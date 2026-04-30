#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ============================================================
; Keyboard + Mouse Daily Heatmap - Enlarged Light Mode UI
; AutoHotkey v2
; ============================================================

recording := false
recordDay := FormatTime(, "yyyy-MM-dd")
viewDay := recordDay
recordCounts := Map()
recordMouseCounts := Map()
counts := recordCounts
mouseCounts := recordMouseCounts
trendCache := Map()
logFile := A_ScriptDir "\keyboard_mouse_daily_log.ini"
web := 0
statusText := 0
dayText := 0
summaryText := 0

K_GRAVE  := Chr(96)
K_BSLASH := Chr(92)
K_QUOTE  := Chr(39)

keyboardSpec := BuildKeyboardSpec()
mainKeys := GetTrackKeys(keyboardSpec)
mouseKeys := ["LButton", "RButton"]

LoadRecordCounts()
BuildGui()
RegisterHotkeys()
UpdateStatus()
RefreshAll()
SetTimer(AutoSave, 5000)
SetTimer(CheckDayRollover, 60000)
SetTimer(PollWebCommands, 200)
OnExit(SaveOnExit)

; -------------------------
; GUI
; -------------------------

BuildGui() {
    global web, statusText, dayText, summaryText

    gui1 := Gui("+Resize +MinSize1280x760", "Keyboard + Mouse Daily Heatmap")
    gui1.BackColor := "F6F4EF"
    gui1.MarginX := 18
    gui1.MarginY := 14

    gui1.SetFont("s18 Bold c1F2420", "Segoe UI")
    gui1.AddText("xm ym w430 h36", "Keyboard + Mouse Daily Heatmap")

    gui1.SetFont("s10 Bold c888888", "Segoe UI")
    statusText := gui1.AddText("x+8 yp+8 w142 h24", "Stopped")

    gui1.SetFont("s10 c676767", "Segoe UI")
    dayText := gui1.AddText("x+8 yp w190 h24", BuildDayLabel())
    summaryText := gui1.AddText("x+14 yp w620 h24", "Selected 0  |  Keyboard 0  |  Mouse 0")

    gui1.SetFont("s10 Bold c202124", "Segoe UI")
    gui1.AddButton("xm y+10 w112 h36", "Start").OnEvent("Click", StartRecording)
    gui1.AddButton("x+9 yp w112 h36", "Stop").OnEvent("Click", StopRecording)
    gui1.AddButton("x+9 yp w132 h36", "Reset Today").OnEvent("Click", ResetTodayCounts)
    gui1.AddButton("x+9 yp w104 h36", "Save").OnEvent("Click", SaveNow)

    gui1.SetFont("s9 c8A867F", "Segoe UI")
    gui1.AddText("x+18 yp+9 w660 h20", "Daily log is saved automatically by calendar day.")

    gui1.AddText("xm y+13 w1888 h1 BackgroundDDD8CF", "")

    web := gui1.AddActiveX("xm y+12 w1888 h790", "Shell.Explorer")
    try web.Value.Silent := true
    web.Value.Navigate("about:blank")
    Loop 70 {
        try {
            if (web.Value.readyState = 4)
                break
        }
        Sleep(30)
    }

    web.Value.document.open()
    web.Value.document.write(BuildHtml())
    web.Value.document.close()

    gui1.OnEvent("Size", GuiSize)
    gui1.OnEvent("Close", GuiClose)

    GetLaunchWorkArea(&workLeft, &workTop, &workRight, &workBottom)
    workW := workRight - workLeft
    workH := workBottom - workTop
    winW := Min(workW - 40, 1320)
    winH := Min(workH - 60, 760)
    if (winW < 1280)
        winW := 1280
    if (winH < 760)
        winH := 760
    posX := workLeft + 300
    posY := workTop + 200
    gui1.Show("x" . posX . " y" . posY . " w" . winW . " h" . winH)
}

GuiSize(guiObj, minMax, width, height) {
    global web
    if (minMax = -1 || !web)
        return
    try web.Move(18, 122, Max(900, width - 36), Max(520, height - 140))
}

GetLaunchWorkArea(&left, &top, &right, &bottom) {
    MouseGetPos(&mx, &my)
    monitorCount := MonitorGetCount()

    Loop monitorCount {
        MonitorGet(A_Index, &monLeft, &monTop, &monRight, &monBottom)
        if (mx >= monLeft && mx < monRight && my >= monTop && my < monBottom) {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
            return
        }
    }

    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
}

BuildHtml() {
    global keyboardSpec
    q := Chr(34)

    css := ""
    css .= "html,body{margin:0;padding:0;background:#F6F4EF;font-family:'Segoe UI',Tahoma,sans-serif;color:#1F2420;overflow:auto;}"
    css .= ".wrap{padding:16px 16px 24px 16px;width:1904px;box-sizing:border-box;}"
    css .= ".top{position:relative;width:1872px;height:324px;margin-bottom:18px;}"
    css .= ".card{position:absolute;box-sizing:border-box;background:#FFFEFB;border:1px solid #DDD7CE;border-radius:24px;box-shadow:0 16px 34px rgba(70,62,50,.10),inset 0 1px 0 rgba(255,255,255,.95);overflow:hidden;}"
    css .= ".mouseCard{left:0;top:0;width:520px;height:324px;}"
    css .= ".overviewCard{left:540px;top:0;width:1332px;height:324px;padding:24px 30px;}"
    css .= ".sectionTitle{position:absolute;left:28px;top:22px;font-size:14px;line-height:18px;font-weight:800;letter-spacing:.9px;color:#83796D;}"
    css .= ".mouseScene{position:absolute;left:103px;top:62px;width:314px;height:210px;}"
    css .= ".mouseBody{position:absolute;left:58px;top:6px;width:220px;height:190px;border:2px solid #C8D2C8;border-radius:108px 108px 80px 80px;background:#EEF6EE;box-shadow:inset 0 2px 0 rgba(255,255,255,.92),0 6px 14px rgba(55,65,55,.10);}"
    css .= ".mousePart{position:absolute;box-sizing:border-box;background:#EEF6EE;border:1px solid rgba(121,138,123,.24);box-shadow:inset 0 1px 0 rgba(255,255,255,.86);text-align:center;overflow:hidden;}"
    css .= ".mouseLeft{left:71px;top:18px;width:92px;height:116px;border-radius:82px 14px 18px 12px;}"
    css .= ".mouseRight{left:171px;top:18px;width:92px;height:116px;border-radius:14px 82px 12px 18px;}"
    css .= ".mouseWheel{position:absolute;left:160px;top:24px;width:18px;height:72px;border-radius:12px;background:linear-gradient(180deg,#F9FBF8 0%,#D5E0D5 100%);border:1px solid rgba(121,138,123,.24);box-shadow:inset 0 1px 0 rgba(255,255,255,.9);}"
    css .= ".mouseDivider{position:absolute;left:168px;top:98px;width:2px;height:28px;background:rgba(122,136,124,.28);border-radius:2px;}"
    css .= ".mousePalm{position:absolute;left:88px;top:134px;width:160px;height:46px;border-top:1px solid rgba(86,101,88,.22);border-radius:0 0 62px 62px;color:#95A096;font-size:11px;text-align:center;padding-top:15px;box-sizing:border-box;}"
    css .= ".mlbl{position:absolute;left:4px;right:4px;top:26px;font-size:14px;font-weight:800;color:#25302A;white-space:nowrap;}"
    css .= ".mcnt{position:absolute;left:4px;right:4px;bottom:18px;font-family:Consolas,'Courier New',monospace;font-size:20px;font-weight:800;color:#4B5B51;}"
    css .= ".overviewHead{display:flex;align-items:flex-start;justify-content:space-between;gap:24px;margin-bottom:14px;}"
    css .= ".overviewTitle{font-size:15px;line-height:20px;font-weight:800;letter-spacing:.9px;color:#83796D;padding-top:4px;}"
    css .= ".overviewActions{text-align:right;white-space:nowrap;padding-top:2px;}"
    css .= ".overviewBtn{display:inline-block;height:34px;margin-left:8px;padding:0 16px;border:1px solid #D8D1C6;border-radius:999px;background:#FFFDF8;color:#26332C;font-size:13px;font-weight:800;letter-spacing:.2px;cursor:pointer;box-shadow:inset 0 1px 0 rgba(255,255,255,.96);}"
    css .= ".overviewBtn:first-child{margin-left:0;}"
    css .= ".overviewBtn.primary{background:#EEF6EE;border-color:#BAC8BB;}"
    css .= ".overviewBtn:disabled{opacity:.45;cursor:default;}"
    css .= ".trendMeta{display:flex;align-items:flex-end;justify-content:space-between;gap:24px;margin-bottom:12px;}"
    css .= ".trendFocus{font-size:28px;line-height:30px;font-weight:800;color:#1F2420;}"
    css .= ".trendRange{font-size:12px;line-height:16px;font-weight:800;letter-spacing:.6px;color:#9A907F;text-transform:uppercase;text-align:right;margin-bottom:4px;}"
    css .= ".trendPanel{height:184px;border:1px solid #E6E0D7;border-radius:22px;background:#FAF8F3;box-shadow:inset 0 1px 0 rgba(255,255,255,.92);padding:14px 18px 14px;box-sizing:border-box;}"
    css .= ".trendSummary{display:flex;align-items:baseline;gap:14px;margin-bottom:10px;white-space:nowrap;}"
    css .= ".trendTotal{font-family:Consolas,'Courier New',monospace;font-size:30px;line-height:32px;font-weight:800;color:#1F2420;}"
    css .= ".trendSplit{font-size:12px;line-height:16px;font-weight:700;color:#746C61;letter-spacing:.2px;}"
    css .= ".trendChart{position:relative;height:92px;overflow:hidden;}"
    css .= ".trendPlot{position:relative;width:1190px;height:92px;margin:0 auto;}"
    css .= ".trendGrid{position:absolute;left:34px;right:8px;height:1px;background:#ECE5DB;}"
    css .= ".trendGrid.top{top:8px;} .trendGrid.mid{top:43px;} .trendGrid.base{top:78px;background:#D7D0C5;}"
    css .= ".trendScale{position:absolute;left:0;width:28px;font-size:10px;line-height:12px;font-weight:700;color:#938878;text-align:left;}"
    css .= ".trendScale.top{top:2px;} .trendScale.base{top:72px;color:#B1A697;}"
    css .= ".trendPixel{position:absolute;width:4px;height:4px;border-radius:999px;background:#2E8B57;z-index:2;}"
    css .= ".trendDot{position:absolute;width:8px;height:8px;border:2px solid #F5FAF5;border-radius:50%;background:#94C89D;box-sizing:border-box;z-index:3;}"
    css .= ".trendDot.current{width:12px;height:12px;border-color:#FFFFFF;background:#1F2420;z-index:4;}"
    css .= ".trendFoot{display:flex;justify-content:space-between;align-items:center;margin-top:8px;font-size:11px;line-height:14px;font-weight:700;color:#9A907F;letter-spacing:.3px;text-transform:uppercase;}"
    css .= ".hiddenCmd{display:none;}"
    css .= ".board{position:relative;width:1872px;height:506px;background:#FFFEFB;border:1px solid #DDD7CE;border-radius:25px;box-shadow:0 18px 38px rgba(70,62,50,.11),inset 0 1px 0 rgba(255,255,255,.95);overflow:hidden;}"
    css .= ".key{position:absolute;box-sizing:border-box;background:#EEF6EE;border:1px solid #BAC8BB;border-bottom:3px solid #A4B3A5;border-radius:12px;box-shadow:inset 0 1px 0 rgba(255,255,255,.92),0 2px 5px rgba(42,50,42,.08);overflow:hidden;text-align:center;}"
    css .= ".key .lbl{position:absolute;left:5px;right:5px;top:9px;font-size:17px;line-height:18px;font-weight:800;color:#202A24;white-space:normal;}"
    css .= ".key .cnt{position:absolute;left:4px;right:4px;bottom:7px;font-family:Consolas,'Courier New',monospace;font-size:16px;line-height:16px;font-weight:800;color:#536259;}"
    css .= ".key.small .lbl{top:8px;font-size:13px;line-height:14px;}"
    css .= ".key.wide .lbl{top:11px;}"
    css .= ".key.space .lbl{top:12px;}"
    css .= ".key.space .cnt{font-size:17px;}"
    css .= ".key.tall .lbl{top:46px;}"
    css .= ".key.tall .cnt{bottom:28px;}"
    css .= ".clusterLabel{position:absolute;top:12px;font-size:10px;font-weight:800;letter-spacing:.7px;color:#B7ADA1;}"

    html := "<!DOCTYPE html><html><head><meta http-equiv=" . q . "X-UA-Compatible" . q . " content=" . q . "IE=edge" . q . "><meta charset=" . q . "utf-8" . q . ">"
    html .= "<style>" . css . "</style>"
    html .= "<script>function setNavCommand(cmd){var el=document.getElementById('nav_action');if(el){el.innerText=cmd;}}</script>"
    html .= "</head><body><div class=" . q . "wrap" . q . ">"

    html .= "<div class=" . q . "top" . q . ">"
    html .= "<div class=" . q . "card mouseCard" . q . "><div class=" . q . "sectionTitle" . q . ">MOUSE</div>"
    html .= "<div class=" . q . "mouseScene" . q . "><div class=" . q . "mouseBody" . q . "></div>"
    html .= MousePartHtml("LButton", "Left", "mousePart mouseLeft", q)
    html .= MousePartHtml("RButton", "Right", "mousePart mouseRight", q)
    html .= "<div class=" . q . "mouseWheel" . q . "></div><div class=" . q . "mouseDivider" . q . "></div>"
    html .= "<div class=" . q . "mousePalm" . q . ">left and right clicks only</div></div></div>"

    html .= "<div class=" . q . "card overviewCard" . q . ">"
    html .= "<div class=" . q . "overviewHead" . q . ">"
    html .= "<div class=" . q . "overviewTitle" . q . ">ACTIVITY TIMELINE</div>"
    html .= "<div class=" . q . "overviewActions" . q . ">"
    html .= "<button id=" . q . "btn_prev" . q . " class=" . q . "overviewBtn" . q . " onclick=" . q . "setNavCommand('prev');return false;" . q . ">Prev Day</button>"
    html .= "<button id=" . q . "btn_today" . q . " class=" . q . "overviewBtn primary" . q . " onclick=" . q . "setNavCommand('today');return false;" . q . ">Today</button>"
    html .= "<button id=" . q . "btn_next" . q . " class=" . q . "overviewBtn" . q . " onclick=" . q . "setNavCommand('next');return false;" . q . ">Next Day</button>"
    html .= "</div></div>"
    html .= "<div class=" . q . "trendMeta" . q . "><div id=" . q . "trend_focus" . q . " class=" . q . "trendFocus" . q . ">--</div><div id=" . q . "trend_range" . q . " class=" . q . "trendRange" . q . ">Past 30 days</div></div>"
    html .= "<div class=" . q . "trendPanel" . q . ">"
    html .= "<div class=" . q . "trendSummary" . q . "><div id=" . q . "trend_total" . q . " class=" . q . "trendTotal" . q . ">0</div><div id=" . q . "trend_split" . q . " class=" . q . "trendSplit" . q . ">Keyboard 0 | Mouse 0</div></div>"
    html .= "<div id=" . q . "trend_chart" . q . " class=" . q . "trendChart" . q . "></div>"
    html .= "<div class=" . q . "trendFoot" . q . "><div id=" . q . "trend_start" . q . ">--</div><div id=" . q . "trend_end" . q . ">--</div></div>"
    html .= "</div><div id=" . q . "nav_action" . q . " class=" . q . "hiddenCmd" . q . "></div>"
    html .= "</div></div>"

    html .= "<div class=" . q . "board" . q . ">"
    html .= "<div class=" . q . "clusterLabel" . q . " style=" . q . "left:22px" . q . ">KEYBOARD</div>"
    html .= "<div class=" . q . "clusterLabel" . q . " style=" . q . "left:1278px" . q . ">NAVIGATION</div>"
    html .= "<div class=" . q . "clusterLabel" . q . " style=" . q . "left:1540px" . q . ">NUMPAD</div>"
    for _, spec in keyboardSpec
        html .= KeyHtml(spec, q)
    html .= "</div></div></body></html>"
    return html
}

MousePartHtml(button, label, cls, q) {
    return "<div id=" . q . MouseToId(button) . q . " class=" . q . cls . q . "><span class=" . q . "mlbl" . q . ">" . HtmlEscape(label) . "</span><span class=" . q . "mcnt" . q . ">0</span></div>"
}

KeyHtml(spec, q) {
    cls := "key"
    if (spec.cls != "")
        cls .= " " . spec.cls
    style := "left:" . spec.x . "px;top:" . spec.y . "px;width:" . spec.w . "px;height:" . spec.h . "px;"
    return "<div id=" . q . KeyToId(spec.key) . q . " class=" . q . cls . q . " style=" . q . style . q . "><span class=" . q . "lbl" . q . ">" . LabelHtml(spec.label) . "</span><span class=" . q . "cnt" . q . ">0</span></div>"
}

LabelHtml(label) {
    return StrReplace(HtmlEscape(label), "`n", "<br>")
}

HtmlEscape(s) {
    s := StrReplace(s, "&", "&amp;")
    s := StrReplace(s, "<", "&lt;")
    s := StrReplace(s, ">", "&gt;")
    s := StrReplace(s, Chr(34), "&quot;")
    return s
}

; -------------------------
; Physical keyboard layout
; -------------------------

BuildKeyboardSpec() {
    global K_GRAVE, K_BSLASH, K_QUOTE

    specs := []
    U := 72, H := 60, G := 8
    mainX := 18
    yF := 30
    y1 := 110
    y2 := 184
    y3 := 258
    y4 := 332
    y5 := 406

    mainW := 15 * U + 14 * G
    navX := mainX + mainW + 64
    numX := navX + 3 * U + 2 * G + 30

    ; Function row
    AddKey(specs, "Esc", "Esc", mainX, yF, U, H)
    x := mainX + U + G + 42
    for _, k in ["F1", "F2", "F3", "F4"] {
        AddKey(specs, k, k, x, yF, U, H)
        x += U + G
    }
    x += 34
    for _, k in ["F5", "F6", "F7", "F8"] {
        AddKey(specs, k, k, x, yF, U, H)
        x += U + G
    }
    x += 34
    for _, k in ["F9", "F10", "F11", "F12"] {
        AddKey(specs, k, k, x, yF, U, H)
        x += U + G
    }

    AddKey(specs, "PrintScreen", "PrtSc", navX, yF, U, H, "small")
    AddKey(specs, "ScrollLock", "ScrLk", navX + U + G, yF, U, H, "small")
    AddKey(specs, "Pause", "Pause", navX + 2 * (U + G), yF, U, H, "small")

    ; Number row
    x := mainX
    for _, k in [K_GRAVE, "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="] {
        AddKey(specs, k, k, x, y1, U, H)
        x += U + G
    }
    AddKey(specs, "Backspace", "Backspace", x, y1, 2 * U + G, H, "wide small")

    ; QWERTY row
    x := mainX
    AddKey(specs, "Tab", "Tab", x, y2, 104, H, "wide")
    x += 104 + G
    for _, k in ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]"] {
        AddKey(specs, k, k, x, y2, U, H)
        x += U + G
    }
    AddKey(specs, K_BSLASH, K_BSLASH, x, y2, 88, H, "wide")

    ; Home row
    x := mainX
    AddKey(specs, "CapsLock", "Caps", x, y3, 122, H, "wide")
    x += 122 + G
    for _, k in ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";", K_QUOTE] {
        AddKey(specs, k, k, x, y3, U, H)
        x += U + G
    }
    AddKey(specs, "Enter", "Enter", x, y3, 126, H, "wide")

    ; Shift row
    x := mainX
    AddKey(specs, "LShift", "Shift", x, y4, 150, H, "wide")
    x += 150 + G
    for _, k in ["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"] {
        AddKey(specs, k, k, x, y4, U, H)
        x += U + G
    }
    AddKey(specs, "RShift", "Shift", x, y4, 162, H, "wide")

    ; Bottom row
    x := mainX
    for _, pair in [["LCtrl", "Ctrl"], ["LWin", "Win"], ["LAlt", "Alt"]] {
        AddKey(specs, pair[1], pair[2], x, y5, 82, H, "wide")
        x += 82 + G
    }
    AddKey(specs, "Space", "Space", x, y5, 450, H, "space")
    x += 450 + G
    for _, pair in [["RAlt", "Alt"], ["RWin", "Win"], ["AppsKey", "Menu"], ["RCtrl", "Ctrl"]] {
        AddKey(specs, pair[1], pair[2], x, y5, 76, H, "wide small")
        x += 76 + G
    }

    ; Navigation cluster
    AddKey(specs, "Insert", "Insert", navX, y1, U, H, "small")
    AddKey(specs, "Home", "Home", navX + U + G, y1, U, H, "small")
    AddKey(specs, "PgUp", "PgUp", navX + 2 * (U + G), y1, U, H, "small")
    AddKey(specs, "Delete", "Delete", navX, y2, U, H, "small")
    AddKey(specs, "End", "End", navX + U + G, y2, U, H, "small")
    AddKey(specs, "PgDn", "PgDn", navX + 2 * (U + G), y2, U, H, "small")

    AddKey(specs, "Up", Chr(0x2191), navX + U + G, y4, U, H)
    AddKey(specs, "Left", Chr(0x2190), navX, y5, U, H)
    AddKey(specs, "Down", Chr(0x2193), navX + U + G, y5, U, H)
    AddKey(specs, "Right", Chr(0x2192), navX + 2 * (U + G), y5, U, H)

    ; Numpad
    AddKey(specs, "NumLock", "Num`nLock", numX, y1, U, H, "small")
    AddKey(specs, "Num/", "/", numX + U + G, y1, U, H)
    AddKey(specs, "Num*", "*", numX + 2 * (U + G), y1, U, H)
    AddKey(specs, "Num-", "-", numX + 3 * (U + G), y1, U, H)

    AddKey(specs, "Num7", "7", numX, y2, U, H)
    AddKey(specs, "Num8", "8", numX + U + G, y2, U, H)
    AddKey(specs, "Num9", "9", numX + 2 * (U + G), y2, U, H)
    AddKey(specs, "Num+", "+", numX + 3 * (U + G), y2, U, 2 * H + G, "tall")

    AddKey(specs, "Num4", "4", numX, y3, U, H)
    AddKey(specs, "Num5", "5", numX + U + G, y3, U, H)
    AddKey(specs, "Num6", "6", numX + 2 * (U + G), y3, U, H)

    AddKey(specs, "Num1", "1", numX, y4, U, H)
    AddKey(specs, "Num2", "2", numX + U + G, y4, U, H)
    AddKey(specs, "Num3", "3", numX + 2 * (U + G), y4, U, H)
    AddKey(specs, "NumEnter", "Enter", numX + 3 * (U + G), y4, U, 2 * H + G, "tall small")

    AddKey(specs, "Num0", "0", numX, y5, 2 * U + G, H, "wide")
    AddKey(specs, "NumDel", ".", numX + 2 * (U + G), y5, U, H)

    return specs
}

AddKey(specs, key, label, x, y, w, h, cls := "") {
    specs.Push({key: key, label: label, x: Round(x), y: Round(y), w: Round(w), h: Round(h), cls: cls})
}

GetTrackKeys(specs) {
    keys := []
    seen := Map()
    for _, spec in specs {
        if !seen.Has(spec.key) {
            seen[spec.key] := true
            keys.Push(spec.key)
        }
    }
    return keys
}

; -------------------------
; IDs, daily save/load
; -------------------------

KeyToId(key) {
    global K_GRAVE, K_BSLASH, K_QUOTE
    switch key {
        case K_GRAVE: return "k_grave"
        case K_BSLASH: return "k_backslash"
        case K_QUOTE: return "k_quote"
        case "-": return "k_minus"
        case "=": return "k_equal"
        case "[": return "k_lbracket"
        case "]": return "k_rbracket"
        case ";": return "k_semicolon"
        case ",": return "k_comma"
        case ".": return "k_period"
        case "/": return "k_slash"
        case "Num/": return "k_num_div"
        case "Num*": return "k_num_mult"
        case "Num-": return "k_num_sub"
        case "Num+": return "k_num_add"
        case "NumDel": return "k_num_decimal"
        case "NumEnter": return "k_num_enter"
    }
    return "k_" . RegExReplace(key, "[^A-Za-z0-9]", "_")
}

MouseToId(button) {
    return "m_" . button
}

KeyboardSection(day) {
    return "Keyboard_" . day
}

MouseSection(day) {
    return "Mouse_" . day
}

TodayString() {
    return FormatTime(, "yyyy-MM-dd")
}

DayKey(day) {
    return StrReplace(day, "-", "")
}

DayAddLabel(day, offset) {
    return FormatTime(DateAdd(DayKey(day) . "000000", offset, "Days"), "yyyy-MM-dd")
}

BuildDayLabel() {
    global viewDay, recordDay
    return (viewDay = recordDay ? "Today " : "Viewing ") . viewDay
}

LoadDayCounts(day) {
    global logFile, mainKeys, mouseKeys

    keyCounts := Map()
    mouseDayCounts := Map()

    if FileExist(logFile) {
        kSection := KeyboardSection(day)
        for _, key in mainKeys {
            id := KeyToId(key)
            v := IniRead(logFile, kSection, id, "")
            if (v != "") {
                try {
                    n := Integer(v)
                } catch {
                    n := 0
                }
                if (n > 0)
                    keyCounts[key] := n
            }
        }

        mSection := MouseSection(day)
        for _, button in mouseKeys {
            v := IniRead(logFile, mSection, button, "")
            if (v != "") {
                try {
                    n := Integer(v)
                } catch {
                    n := 0
                }
                if (n > 0)
                    mouseDayCounts[button] := n
            }
        }
    }

    UpdateTrendCache(day, keyCounts, mouseDayCounts)
    return {keys: keyCounts, mouse: mouseDayCounts}
}

LoadRecordCounts() {
    global recordDay, viewDay, recordCounts, recordMouseCounts, counts, mouseCounts

    snapshot := LoadDayCounts(recordDay)
    recordCounts := snapshot.keys
    recordMouseCounts := snapshot.mouse

    if (viewDay = recordDay) {
        counts := recordCounts
        mouseCounts := recordMouseCounts
    }
}

SaveDayCounts(day, keyCounts, mouseDayCounts) {
    global logFile, mainKeys, mouseKeys

    kSection := KeyboardSection(day)
    for _, key in mainKeys {
        id := KeyToId(key)
        val := keyCounts.Has(key) ? keyCounts[key] : 0
        IniWrite(val, logFile, kSection, id)
    }

    mSection := MouseSection(day)
    for _, button in mouseKeys {
        val := mouseDayCounts.Has(button) ? mouseDayCounts[button] : 0
        IniWrite(val, logFile, mSection, button)
    }

    UpdateTrendCache(day, keyCounts, mouseDayCounts)
    IniWrite(FormatTime(, "yyyy-MM-dd HH:mm:ss"), logFile, "Meta", "LastSaved")
}

SaveRecordCounts() {
    global recordDay, recordCounts, recordMouseCounts
    SaveDayCounts(recordDay, recordCounts, recordMouseCounts)
}

AutoSave() {
    SaveRecordCounts()
}

SaveNow(*) {
    SaveRecordCounts()
    UpdateStatus()
}

SaveOnExit(*) {
    SaveRecordCounts()
}

GuiClose(*) {
    SaveRecordCounts()
    ExitApp
}

CheckDayRollover(*) {
    global recordDay, viewDay
    today := TodayString()
    if (today = recordDay)
        return

    wasViewingToday := (viewDay = recordDay)
    SaveRecordCounts()
    recordDay := today
    LoadRecordCounts()
    if wasViewingToday
        AdoptViewDay(recordDay)
    RefreshAll()
    UpdateStatus()
}

; -------------------------
; Hotkeys
; -------------------------

RegisterHotkeys() {
    global K_GRAVE, K_BSLASH, K_QUOTE

    for _, k in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
        TryHotkey("~*" . k, CountKey.Bind(k))

    for _, k in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        TryHotkey("~*" . k, CountKey.Bind(k))

    Loop 12
        TryHotkey("~*F" . A_Index, CountKey.Bind("F" . A_Index))

    TryHotkey("~*``", CountKey.Bind(K_GRAVE))
    TryHotkey("~*-", CountKey.Bind("-"))
    TryHotkey("~*=", CountKey.Bind("="))
    TryHotkey("~*[", CountKey.Bind("["))
    TryHotkey("~*]", CountKey.Bind("]"))
    TryHotkey("~*\", CountKey.Bind(K_BSLASH))
    TryHotkey("~*;", CountKey.Bind(";"))
    TryHotkey("~*'", CountKey.Bind(K_QUOTE))
    TryHotkey("~*,", CountKey.Bind(","))
    TryHotkey("~*.", CountKey.Bind("."))
    TryHotkey("~*/", CountKey.Bind("/"))

    hotkeyMap := Map(
        "~*Esc", "Esc",
        "~*Backspace", "Backspace",
        "~*Tab", "Tab",
        "~*CapsLock", "CapsLock",
        "~*Enter", "Enter",
        "~*LShift", "LShift",
        "~*RShift", "RShift",
        "~*LCtrl", "LCtrl",
        "~*RCtrl", "RCtrl",
        "~*LAlt", "LAlt",
        "~*RAlt", "RAlt",
        "~*LWin", "LWin",
        "~*RWin", "RWin",
        "~*AppsKey", "AppsKey",
        "~*Space", "Space",
        "~*PrintScreen", "PrintScreen",
        "~*ScrollLock", "ScrollLock",
        "~*Pause", "Pause",
        "~*Insert", "Insert",
        "~*Home", "Home",
        "~*PgUp", "PgUp",
        "~*Delete", "Delete",
        "~*End", "End",
        "~*PgDn", "PgDn",
        "~*Left", "Left",
        "~*Down", "Down",
        "~*Up", "Up",
        "~*Right", "Right",
        "~*NumLock", "NumLock",
        "~*NumpadDiv", "Num/",
        "~*NumpadMult", "Num*",
        "~*NumpadSub", "Num-",
        "~*NumpadAdd", "Num+",
        "~*NumpadEnter", "NumEnter",
        "~*Numpad0", "Num0",
        "~*Numpad1", "Num1",
        "~*Numpad2", "Num2",
        "~*Numpad3", "Num3",
        "~*Numpad4", "Num4",
        "~*Numpad5", "Num5",
        "~*Numpad6", "Num6",
        "~*Numpad7", "Num7",
        "~*Numpad8", "Num8",
        "~*Numpad9", "Num9",
        "~*NumpadDot", "NumDel",
        "~*NumpadDel", "NumDel",
        "~*NumpadIns", "Num0",
        "~*NumpadEnd", "Num1",
        "~*NumpadDown", "Num2",
        "~*NumpadPgDn", "Num3",
        "~*NumpadLeft", "Num4",
        "~*NumpadClear", "Num5",
        "~*NumpadRight", "Num6",
        "~*NumpadHome", "Num7",
        "~*NumpadUp", "Num8",
        "~*NumpadPgUp", "Num9"
    )

    for hk, keyName in hotkeyMap
        TryHotkey(hk, CountKey.Bind(keyName))

    for _, pair in [["~*LButton", "LButton"], ["~*RButton", "RButton"]]
        TryHotkey(pair[1], CountMouse.Bind(pair[2]))
}

TryHotkey(hk, fn) {
    try Hotkey(hk, fn, "On")
}

CountKey(key, *) {
    global recording, viewDay, recordDay, recordCounts, recordMouseCounts
    if !recording
        return
    CheckDayRollover()
    recordCounts[key] := recordCounts.Has(key) ? recordCounts[key] + 1 : 1
    UpdateTrendCache(recordDay, recordCounts, recordMouseCounts)
    if (viewDay = recordDay) {
        UpdateKeyVisual(key)
        UpdateSummary()
    }
}

CountMouse(button, *) {
    global recording, viewDay, recordDay, recordCounts, recordMouseCounts
    if !recording
        return
    CheckDayRollover()
    recordMouseCounts[button] := recordMouseCounts.Has(button) ? recordMouseCounts[button] + 1 : 1
    UpdateTrendCache(recordDay, recordCounts, recordMouseCounts)
    if (viewDay = recordDay) {
        UpdateMouseVisual(button)
        UpdateSummary()
    }
}

; -------------------------
; State + rendering
; -------------------------

StartRecording(*) {
    global recording
    CheckDayRollover()
    recording := true
    UpdateStatus()
}

StopRecording(*) {
    global recording
    recording := false
    SaveRecordCounts()
    UpdateStatus()
}

ResetTodayCounts(*) {
    global recordDay, viewDay, recordCounts, recordMouseCounts, counts, mouseCounts
    recordCounts := Map()
    recordMouseCounts := Map()
    UpdateTrendCache(recordDay, recordCounts, recordMouseCounts)
    if (viewDay = recordDay) {
        counts := recordCounts
        mouseCounts := recordMouseCounts
    }
    SaveRecordCounts()
    RefreshAll()
    UpdateStatus()
}

UpdateStatus() {
    global statusText, dayText, recording
    if recording {
        statusText.Value := "Recording"
        statusText.Opt("c2E8B57")
    } else {
        statusText.Value := "Stopped"
        statusText.Opt("c8A8A8A")
    }
    if dayText
        dayText.Value := BuildDayLabel()
    UpdateSummary()
}

UpdateSummary() {
    global summaryText, counts, mouseCounts, web
    if !summaryText
        return

    metrics := GetMetrics(counts, mouseCounts)
    summaryText.Value := "Selected " . metrics.total . "  |  Keyboard " . metrics.keyboard . "  |  Mouse " . metrics.mouse

    if web
        UpdateTrendPanel(metrics)
}

SetDomText(id, text) {
    global web
    try {
        el := web.Value.document.getElementById(id)
        if el
            el.innerText := text
    }
}

SetDomHtml(id, html) {
    global web
    try {
        el := web.Value.document.getElementById(id)
        if el
            el.innerHTML := html
    }
}

SetDomDisabled(id, disabled) {
    global web
    try {
        el := web.Value.document.getElementById(id)
        if el
            el.disabled := disabled ? true : false
    }
}

RefreshAll() {
    RefreshKeyboard()
    RefreshMouse()
    UpdateSummary()
}

RefreshKeyboard() {
    global mainKeys
    for _, key in mainKeys
        UpdateKeyVisual(key)
}

RefreshMouse() {
    global mouseKeys
    for _, button in mouseKeys
        UpdateMouseVisual(button)
}

UpdateKeyVisual(key) {
    global web, counts
    if !web
        return
    try {
        el := web.Value.document.getElementById(KeyToId(key))
        if !el
            return
        count := counts.Has(key) ? counts[key] : 0
        spans := el.getElementsByTagName("span")
        if (spans.length >= 2) {
            spans.item(1).innerText := count
            textColor := CountToTextColorKeyboard(count)
            spans.item(0).style.color := textColor
            spans.item(1).style.color := textColor
        }
        el.style.backgroundColor := CountToKeyboardColor(count)
        el.title := key . ": " . count
    }
}

UpdateMouseVisual(button) {
    global web, mouseCounts
    if !web
        return
    try {
        el := web.Value.document.getElementById(MouseToId(button))
        if !el
            return
        count := mouseCounts.Has(button) ? mouseCounts[button] : 0
        spans := el.getElementsByTagName("span")
        if (spans.length >= 2) {
            spans.item(1).innerText := count
            textColor := CountToTextColorMouse(count)
            spans.item(0).style.color := textColor
            spans.item(1).style.color := textColor
        }
        el.style.backgroundColor := CountToMouseColor(count)
        el.title := button . ": " . count
    }
}

GetMetrics(keyCounts, mouseDayCounts) {
    keyboardTotal := 0
    mouseTotal := 0

    for _, v in keyCounts
        keyboardTotal += v
    for _, v in mouseDayCounts
        mouseTotal += v

    return {keyboard: keyboardTotal, mouse: mouseTotal, total: keyboardTotal + mouseTotal}
}

UpdateTrendCache(day, keyCounts, mouseDayCounts) {
    global trendCache
    metrics := GetMetrics(keyCounts, mouseDayCounts)
    trendCache[day] := metrics
    return metrics
}

GetDayTotals(day) {
    global recordDay, recordCounts, recordMouseCounts, trendCache

    if (day = recordDay)
        return UpdateTrendCache(day, recordCounts, recordMouseCounts)

    if trendCache.Has(day)
        return trendCache[day]

    snapshot := LoadDayCounts(day)
    return UpdateTrendCache(day, snapshot.keys, snapshot.mouse)
}

NiceTrendMax(value) {
    if (value <= 0)
        return 10
    if (value <= 50)
        return Ceil(value / 10) * 10
    if (value <= 500)
        return Ceil(value / 50) * 50
    if (value <= 2000)
        return Ceil(value / 100) * 100
    if (value <= 5000)
        return Ceil(value / 250) * 250
    return Ceil(value / 500) * 500
}

BuildTrendChartHtml(startDay) {
    chartW := 1190
    chartH := 92
    leftPad := 34
    rightPad := 8
    topPad := 8
    bottomPad := 14
    plotW := chartW - leftPad - rightPad
    plotH := chartH - topPad - bottomPad
    baselineY := topPad + plotH
    series := []
    points := []
    html := "<div class='trendPlot'>"
    maxTotal := 0

    Loop 30 {
        day := DayAddLabel(startDay, A_Index - 1)
        totals := GetDayTotals(day)
        if (totals.total > maxTotal)
            maxTotal := totals.total
        series.Push({day: day, total: totals.total})
    }

    scaleMax := NiceTrendMax(maxTotal)
    pointCount := series.Length
    html .= "<div class='trendGrid top'></div><div class='trendGrid mid'></div><div class='trendGrid base'></div>"
    html .= "<div class='trendScale top'>" . scaleMax . "</div><div class='trendScale base'>0</div>"

    for index, item in series {
        x := leftPad + ((index - 1) * plotW / Max(1, pointCount - 1))
        y := baselineY - ((item.total / scaleMax) * plotH)
        points.Push({x: x, y: y, day: item.day, total: item.total})
    }

    for index, point in points {
        if (index >= pointCount)
            break
        nextPoint := points[index + 1]
        dx := nextPoint.x - point.x
        dy := nextPoint.y - point.y
        samples := Max(1, Ceil(Abs(dx) / 3))

        Loop samples + 1 {
            step := (A_Index - 1) / samples
            px := point.x + (dx * step)
            py := point.y + (dy * step)
            html .= "<div class='trendPixel' style='left:" . Round(px - 2, 1) . "px;top:" . Round(py - 2, 1) . "px;'></div>"
        }
    }

    for index, point in points {
        dotSize := (index = pointCount ? 12 : 8)
        cls := (index = pointCount ? "trendDot current" : "trendDot")
        title := point.day . " | " . point.total
        html .= "<div class='" . cls . "' title='" . title . "' style='left:" . Round(point.x - (dotSize / 2), 1) . "px;top:" . Round(point.y - (dotSize / 2), 1) . "px;'></div>"
    }

    html .= "</div>"
    return html
}

UpdateTrendPanel(metrics := 0) {
    global web, viewDay, recordDay, counts, mouseCounts
    if !web
        return

    if !IsObject(metrics)
        metrics := GetMetrics(counts, mouseCounts)

    startDay := DayAddLabel(viewDay, -29)
    SetDomText("trend_focus", viewDay)
    SetDomText("trend_range", "Past 30 days ending " . viewDay)
    SetDomText("trend_total", metrics.total)
    SetDomText("trend_split", "Keyboard " . metrics.keyboard . " | Mouse " . metrics.mouse)
    SetDomText("trend_start", startDay)
    SetDomText("trend_end", viewDay)
    SetDomHtml("trend_chart", BuildTrendChartHtml(startDay))
    SetDomDisabled("btn_today", viewDay = recordDay)
    SetDomDisabled("btn_next", viewDay = recordDay)
}

AdoptViewDay(day) {
    global viewDay, recordDay, counts, mouseCounts, recordCounts, recordMouseCounts

    viewDay := day
    if (day = recordDay) {
        counts := recordCounts
        mouseCounts := recordMouseCounts
        return
    }

    snapshot := LoadDayCounts(day)
    counts := snapshot.keys
    mouseCounts := snapshot.mouse
}

ShowViewDay(day) {
    AdoptViewDay(day)
    RefreshAll()
    UpdateStatus()
}

GoRelativeDay(offset) {
    global viewDay, recordDay
    target := DayAddLabel(viewDay, offset)
    if (DayKey(target) > DayKey(recordDay))
        target := recordDay
    if (target = viewDay)
        return
    ShowViewDay(target)
}

GoToday() {
    global recordDay
    if (recordDay != "")
        ShowViewDay(recordDay)
}

PollWebCommands(*) {
    global web
    if !web
        return
    try {
        el := web.Value.document.getElementById("nav_action")
        if !el
            return
        cmd := Trim(el.innerText)
        if (cmd = "")
            return
        el.innerText := ""
        switch cmd {
            case "prev":
                GoRelativeDay(-1)
            case "next":
                GoRelativeDay(1)
            case "today":
                GoToday()
        }
    }
}

; Keyboard: designed for a full graduate-student daily typing workload.
; Mouse: designed for much larger daily click counts, especially left-click usage.
CountToKeyboardColor(count) {
    if (count <= 0)
        return "#EEF6EE"
    if (count <= 49)
        return "#E2F1E4"
    if (count <= 149)
        return "#C8E9CB"
    if (count <= 349)
        return "#9FD6A1"
    if (count <= 699)
        return "#FFF0B3"
    if (count <= 1199)
        return "#FFD177"
    if (count <= 1999)
        return "#FF9B6A"
    if (count <= 3999)
        return "#ED5F5F"
    return "#B83737"
}

CountToMouseColor(count) {
    if (count <= 0)
        return "#EEF6EE"
    if (count <= 99)
        return "#E2F1E4"
    if (count <= 299)
        return "#C8E9CB"
    if (count <= 799)
        return "#9FD6A1"
    if (count <= 1499)
        return "#FFF0B3"
    if (count <= 2999)
        return "#FFD177"
    if (count <= 5999)
        return "#FF9B6A"
    if (count <= 9999)
        return "#ED5F5F"
    return "#B83737"
}

CountToTextColorKeyboard(count) {
    if (count >= 2000)
        return "#FFFFFF"
    return "#202A24"
}

CountToTextColorMouse(count) {
    if (count >= 6000)
        return "#FFFFFF"
    return "#202A24"
}
