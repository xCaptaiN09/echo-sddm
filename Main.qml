// Echo SDDM Theme — Main.qml
// macOS Terminal aesthetic | xCaptaiN09
// Qt6 only. Requires qt6-5compat for frosted glass blur.

import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects 1.0
import SddmComponents 2.0

Rectangle {
    id: root
    width:  Screen.width
    height: Screen.height
    color:  "#0d0d0d"
    focus:  true

    // ─── Config ───────────────────────────────────────────────────────────────
    property string themeType: config.type        || "pure"
    property string loginMode: config.login_mode  || "select"
    property string bgPath:    config.background  || ""
    property string cfgFont:   config.font        || "JetBrains Mono"
    property int    fontSize:  parseInt(config.font_size)     > 0 ? parseInt(config.font_size)     : 14
    property int    bootMs:    parseInt(config.boot_interval) > 0 ? parseInt(config.boot_interval) : 72
    property real   bgOpacity:  parseFloat(config.background_opacity) > 0 ? parseFloat(config.background_opacity) : 0.78
    property int    blurRadius: parseInt(config.blur_radius) > 0 ? parseInt(config.blur_radius) : 54
    property bool   use24h:    config.use_24h !== "false" && config.use_24h !== "0"
    property string timeFmt:   use24h ? "HH:mm" : "h:mm AP"
    property string dateTimeFmt: use24h ? "ddd dd MMM  HH:mm" : "ddd dd MMM  h:mm AP"

    // ─── Real system info ─────────────────────────────────────────────────────
    property string realDistro: "Arch Linux"
    property string realKernel: ""
    property string realUptime: ""

    // Adaptive text colors: brighter in frosted mode for readability
    property bool isFrosted: bgImage.visible
    property string txtDim:    isFrosted ? "#88888c" : "#444448"
    property string txtMid:    isFrosted ? "#a0a0a8" : "#636368"
    property string txtBright: isFrosted ? "#c0c0c8" : "#bebec2"
    property string txtOrange: isFrosted ? "#f0b060" : "#e8a041"
    property string clockClr:  isFrosted ? "#a0a0a8" : "#3e3e42"

    function readFile(path) {
        try {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", path, false)
            xhr.send()
            if (xhr.status === 200 || xhr.status === 0) return xhr.responseText || ""
            return ""
        } catch(e) {
            return ""
        }
    }

    function loadSysInfo() {
        var osrel = readFile("/etc/os-release")
        var dm = osrel.match(/PRETTY_NAME="([^"]+)"/)
        if (dm) realDistro = dm[1]

        var ver = readFile("/proc/version")
        var km = ver.match(/Linux version (\S+)/)
        if (km) realKernel = km[1]

        var up = readFile("/proc/uptime")
        var parts = up.split(" ")
        var secs = parts.length > 0 ? parseFloat(parts[0]) : NaN
        if (!isNaN(secs)) {
            var h = Math.floor(secs / 3600)
            var m = Math.floor((secs % 3600) / 60)
            realUptime = h > 0 ? h + "h " + m + "m" : m + "m"
        }
    }

    Component.onCompleted: {
        try { loadSysInfo() } catch(e) { console.log("loadSysInfo error:", e) }
        try { buildBootLog() } catch(e) { console.log("buildBootLog error:", e) }
    }

    property string dispHost: sddm.hostName.length > 0 ? sddm.hostName : "localhost"

    // ─── State ────────────────────────────────────────────────────────────────
    property int    bootStep:   0
    property bool   bootDone:   false
    property bool   didFail:    false
    property string failMsg:    ""
    property int    userIdx:    0
    property int    sessIdx:    sessionModel.lastIndex
    property int    ttySession: sessionModel.lastIndex
    property int    focusRow:   0

    // ─── Helpers ──────────────────────────────────────────────────────────────
    property var mockUsers:    ["captain", "guest"]
    property var mockSessions: ["hyprland", "hyprland-uwsm"]
    property bool isTestMode:  userModel.rowCount() === 0

    Repeater {
        id: userRep; model: userModel
        delegate: Item { visible:false; width:0; height:0
            property string loginName: model.name || "" }
    }
    Repeater {
        id: sessRep; model: sessionModel
        delegate: Item { visible:false; width:0; height:0
            property string sessName: model.name || "" }
    }

    function userName(i) {
        if (userRep.count === 0) return mockUsers[i] || ""
        var item = userRep.itemAt(i)
        return item ? item.loginName : ""
    }

    function sessName(i) {
        if (sessRep.count === 0) return mockSessions[i] || ""
        var item = sessRep.itemAt(i)
        var raw = item ? item.sessName : ""
        if (raw.indexOf("/") !== -1) raw = raw.substring(raw.lastIndexOf("/") + 1)
        if (raw.endsWith(".desktop")) raw = raw.substring(0, raw.length - 8)
        return raw || "session"
    }

    function userCount() { return userRep.count === 0 ? mockUsers.length    : userModel.rowCount()    }
    function sessCount() { return sessRep.count === 0 ? mockSessions.length : sessionModel.rowCount() }

    function doLogin(user, pwd, sess) {
        didFail = false
        failMsg = ""
        sddm.login(user, pwd, sess)
    }

    // ─── SDDM signals ─────────────────────────────────────────────────────────
    Connections {
        target: sddm
        function onLoginSucceeded() {}
        function onLoginFailed() {
            didFail = true
            failMsg = "Login incorrect"
            if (loginMode === "tty") {
                ttyPwd.text = ""
                ttyPwd.forceActiveFocus()
            } else {
                pwdInput.text = ""
                pwdInput.forceActiveFocus()
            }
        }
    }

    // ─── Keyboard ─────────────────────────────────────────────────────────────
    Keys.onPressed: function(event) {
        if (!bootDone) return

        if (loginMode === "tty") {
            if (event.key === Qt.Key_F1) {
                ttySession = (ttySession - 1 + sessCount()) % sessCount()
                event.accepted = true
            } else if (event.key === Qt.Key_F2) {
                ttySession = (ttySession + 1) % sessCount()
                event.accepted = true
            }
        } else if (loginMode === "select") {
            if (event.key === Qt.Key_Left) {
                if (focusRow === 0) userIdx = (userIdx - 1 + userCount()) % userCount()
                else if (focusRow === 1) sessIdx = (sessIdx - 1 + sessCount()) % sessCount()
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (focusRow === 0) userIdx = (userIdx + 1) % userCount()
                else if (focusRow === 1) sessIdx = (sessIdx + 1) % sessCount()
                event.accepted = true
            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                focusRow = (focusRow + 1) % 3
                if (focusRow === 2) pwdInput.forceActiveFocus()
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                focusRow = (focusRow - 1 + 3) % 3
                if (focusRow === 2) pwdInput.forceActiveFocus()
                event.accepted = true
            }
        }
    }

    // ─── Wallpaper ────────────────────────────────────────────────────────────
    Image {
        id: bgImage
        anchors.fill: parent
        source:       themeType === "frosted" && bgPath.length > 0 ? bgPath : ""
        fillMode:     Image.PreserveAspectCrop
        visible:      themeType === "frosted" && bgPath.length > 0
    }

    // ─── Terminal window ──────────────────────────────────────────────────────
    Rectangle {
        id: termWin
        width:  Math.min(760, root.width * 0.60)
        height: Math.max(460, termCol.y + termCol.height + 28)
        radius: 11
        color:  "transparent"
        anchors.centerIn: parent

        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // ── Frosted glass ─────────────────────────────────────────────────────
        Item {
            id: glassLayer
            anchors.fill: parent
            visible: bgImage.visible

            ShaderEffectSource {
                id: bgCap
                sourceItem: bgImage
                sourceRect: Qt.rect(termWin.x, termWin.y, termWin.width, termWin.height)
                anchors.fill: parent
                visible: false
                live: true
            }
            FastBlur {
                anchors.fill: parent
                source: bgCap
                radius: blurRadius
            }
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width:   glassLayer.width
                    height:  glassLayer.height
                    radius:  termWin.radius
                    visible: false
                }
            }
        }

        // ── Window background ─────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius:       termWin.radius
            color:        bgImage.visible ? Qt.rgba(0.06, 0.06, 0.06, bgOpacity) : "#1c1c1e"
            border.color: bgImage.visible ? Qt.rgba(1, 1, 1, 0.09)          : "#303034"
            border.width: 1
        }

        // ── Title bar ─────────────────────────────────────────────────────────
        Rectangle {
            id: titleBar
            width:  parent.width
            height: 38
            radius: termWin.radius
            color:  bgImage.visible ? Qt.rgba(0.10, 0.10, 0.10, 0.92) : "#232326"

            Rectangle {
                width: parent.width; height: termWin.radius
                anchors.bottom: parent.bottom
                color: parent.color
            }
            Rectangle {
                width: parent.width; height: 1
                anchors.bottom: parent.bottom
                color: bgImage.visible ? Qt.rgba(1,1,1,0.07) : "#2c2c2f"
            }

            // Traffic lights
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 13; height: 13; radius: 7
                    color: h ? "#ff3a2f" : "#ff5f57"
                    property bool h: false
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -1
                        text: "⏻"; font.pixelSize: 8; color: "#0d0d0d"
                        visible: parent.h
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.h = true
                        onExited:  parent.h = false
                        onClicked: sddm.powerOff()
                    }
                }
                Rectangle {
                    width: 13; height: 13; radius: 7
                    color: h ? "#ffaa00" : "#febc2e"
                    property bool h: false
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -1
                        text: "↺"; font.pixelSize: 8; color: "#0d0d0d"
                        visible: parent.h
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.h = true
                        onExited:  parent.h = false
                        onClicked: sddm.reboot()
                    }
                }
                Rectangle {
                    width: 13; height: 13; radius: 7
                    color: h ? "#1aaa30" : "#28c840"
                    property bool h: false
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "⏾"; font.pixelSize: 8; color: "#0d0d0d"
                        visible: parent.h
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.h = true
                        onExited:  parent.h = false
                        onClicked: sddm.suspend()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text:           ">_  " + dispHost + " — zsh — 80x24"
                font.family:    cfgFont
                font.pixelSize: 13
                color:          txtMid
            }
        }

        // ── Content ───────────────────────────────────────────────────────────
        Column {
            id: termCol
            anchors.top:         titleBar.bottom
            anchors.left:        parent.left
            anchors.right:       parent.right
            anchors.topMargin:   16
            anchors.leftMargin:  22
            anchors.rightMargin: 22
            spacing: 1

            // Boot log
            Repeater {
                model: bootStep
                delegate: Row {
                    spacing: 0
                    Text { text: "[ ";  font.family: cfgFont; font.pixelSize: fontSize; color: txtBright }
                    Text {
                        text:  bootLog[index].s === "OK" ? " OK " : "FAIL"
                        font.family: cfgFont; font.pixelSize: fontSize
                        color: bootLog[index].s === "OK" ? "#4ec94e" : "#e05252"
                    }
                    Text { text: " ] " + bootLog[index].m; font.family: cfgFont; font.pixelSize: fontSize; color: txtBright }
                }
            }

            Item { width: 1; height: 14; visible: bootDone }

            // Sysinfo
            Text {
                id: sysInfo
                visible: bootDone
                opacity: 0.0
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                font.family: cfgFont; font.pixelSize: fontSize; color: txtBright
                property string curTime: Qt.formatTime(new Date(), timeFmt)
                text: dispHost + "  |  " + realDistro
                    + (realUptime.length > 0 ? "  |  up " + realUptime : "")
                    + "  |  " + curTime
                Timer { interval: 30000; running: true; repeat: true
                    onTriggered: sysInfo.curTime = Qt.formatTime(new Date(), timeFmt) }
            }

            Item { width: 1; height: 18; visible: bootDone }

            // ── TTY mode ──────────────────────────────────────────────────────
            Column {
                id: ttyBlock
                visible: bootDone && loginMode === "tty"
                opacity: 0.0
                spacing: 2
                width: parent.width
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                Row {
                    spacing: 0
                    Text { text: dispHost + " login: "; font.family: cfgFont; font.pixelSize: fontSize; color: txtBright }
                    TextInput {
                        id: ttyUser
                        font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2"
                        cursorDelegate: Item {}
                        selectByMouse: false
                        Keys.onReturnPressed: function(e) { e.accepted = true; ttyPwd.forceActiveFocus() }
                        Keys.onTabPressed:    function(e) { e.accepted = true; ttyPwd.forceActiveFocus() }
                        Keys.onPressed: function(e) {
                            if (e.key === Qt.Key_F1)      { ttySession = (ttySession - 1 + sessCount()) % sessCount(); e.accepted = true }
                            else if (e.key === Qt.Key_F2) { ttySession = (ttySession + 1) % sessCount(); e.accepted = true }
                        }
                    }
                    Rectangle {
                        width: 9; height: fontSize + 3; color: txtBright
                        visible: ttyUser.activeFocus
                        SequentialAnimation on opacity {
                            running: visible; loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: 0 }
                            PauseAnimation  { duration: 530 }
                            NumberAnimation { to: 0.0; duration: 0 }
                            PauseAnimation  { duration: 530 }
                        }
                    }
                }

                Row {
                    spacing: 0
                    Text { text: "Password: "; font.family: cfgFont; font.pixelSize: fontSize; color: txtBright }
                    TextInput {
                        id: ttyPwd
                        font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2"
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        cursorDelegate: Item {}
                        selectByMouse: false
                        Keys.onReturnPressed: function(e) { e.accepted = true; doLogin(ttyUser.text, ttyPwd.text, ttySession) }
                        Keys.onTabPressed:    function(e) { e.accepted = true; ttyUser.forceActiveFocus() }
                        Keys.onPressed: function(e) {
                            if (e.key === Qt.Key_F1)      { ttySession = (ttySession - 1 + sessCount()) % sessCount(); e.accepted = true }
                            else if (e.key === Qt.Key_F2) { ttySession = (ttySession + 1) % sessCount(); e.accepted = true }
                        }
                    }
                    Rectangle {
                        width: 9; height: fontSize + 3; color: txtBright
                        visible: ttyPwd.activeFocus
                        SequentialAnimation on opacity {
                            running: visible; loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: 0 }
                            PauseAnimation  { duration: 530 }
                            NumberAnimation { to: 0.0; duration: 0 }
                            PauseAnimation  { duration: 530 }
                        }
                    }
                }

                // TTY-style inline error
                Row {
                    visible: didFail && loginMode === "tty"
                    spacing: 0
                    Text {
                        text: failMsg
                        font.family: cfgFont; font.pixelSize: fontSize; color: "#e05252"
                        opacity: didFail ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                Item { width: 1; height: 10 }
                Row {
                    spacing: 0
                    Text { text: "[F1] [F2] session: "; font.family: cfgFont; font.pixelSize: fontSize - 1; color: txtDim }
                    Text { text: sessName(ttySession); font.family: cfgFont; font.pixelSize: fontSize - 1; color: txtMid }
                }
            }

            // ── Select mode ───────────────────────────────────────────────────
            Column {
                id: selectBlock
                visible: bootDone && loginMode === "select"
                opacity: 0.0
                spacing: 2
                width: parent.width
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                Row {
                    spacing: 0
                    Text { text: "user:     "; font.family: cfgFont; font.pixelSize: fontSize; color: txtOrange }
                    Text { text: userName(userIdx); font.family: cfgFont; font.pixelSize: fontSize; color: txtOrange }
                    Text {
                        text: "  ◀ ▶"; font.family: cfgFont; font.pixelSize: fontSize
                        color: focusRow === 0 ? "#e8a041" : "#444448"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                Row {
                    spacing: 0
                    Text { text: "session:  "; font.family: cfgFont; font.pixelSize: fontSize; color: txtBright }
                    Text { text: sessName(sessIdx); font.family: cfgFont; font.pixelSize: fontSize; color: txtBright }
                    Text {
                        text: "  ◀ ▶"; font.family: cfgFont; font.pixelSize: fontSize
                        color: focusRow === 1 ? "#ffffff" : "#444448"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                Row {
                    spacing: 0
                    Text { text: "password: "; font.family: cfgFont; font.pixelSize: fontSize; color: txtBright }
                    TextInput {
                        id: pwdInput
                        font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2"
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        cursorDelegate: Item {}
                        selectByMouse: false
                        Keys.onReturnPressed:  function(e) { e.accepted = true; doLogin(userName(userIdx), pwdInput.text, sessIdx) }
                        Keys.onTabPressed:     function(e) { e.accepted = true; focusRow = 0; root.forceActiveFocus() }
                        Keys.onBacktabPressed: function(e) { e.accepted = true; focusRow = 1; root.forceActiveFocus() }
                        Keys.onUpPressed:      function(e) { e.accepted = true; focusRow = 1; root.forceActiveFocus() }
                    }
                    Rectangle {
                        width: 9; height: fontSize + 3; color: txtBright
                        visible: pwdInput.activeFocus
                        SequentialAnimation on opacity {
                            running: visible; loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: 0 }
                            PauseAnimation  { duration: 530 }
                            NumberAnimation { to: 0.0; duration: 0 }
                            PauseAnimation  { duration: 530 }
                        }
                    }
                }

                // Select-mode inline error
                Row {
                    visible: didFail && loginMode === "select"
                    spacing: 0
                    Text {
                        text: failMsg
                        font.family: cfgFont; font.pixelSize: fontSize; color: "#e05252"
                        opacity: didFail ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }

            // Lock indicators (both modes)
            Column {
                visible: bootDone
                spacing: 1
                width: parent.width

                Row {
                    visible: typeof keyboard !== "undefined" && keyboard.capsLock
                    spacing: 4
                    Text { text: "⚠"; font.family: cfgFont; font.pixelSize: fontSize - 1; color: "#e8853a" }
                    Text { text: "Caps Lock is on"; font.family: cfgFont; font.pixelSize: fontSize - 1; color: "#e8853a" }
                }
                Row {
                    visible: typeof keyboard !== "undefined" && keyboard.numLock
                    spacing: 4
                    Text { text: "⚠"; font.family: cfgFont; font.pixelSize: fontSize - 1; color: "#e8853a" }
                    Text { text: "Num Lock is on"; font.family: cfgFont; font.pixelSize: fontSize - 1; color: "#e8853a" }
                }
            }

            Item { width: 1; height: 20; visible: bootDone }

            Item { width: 1; height: 24 }
        }
    }

    // ─── Boot timer ───────────────────────────────────────────────────────────
    Timer {
        interval: bootMs; running: true; repeat: true
        onTriggered: {
            if (bootStep < bootLog.length) {
                bootStep++
            } else {
                running = false
                bootDone = true
                sysInfo.opacity     = 1.0
                ttyBlock.opacity    = 1.0
                selectBlock.opacity = 1.0
                if (loginMode === "tty") ttyUser.forceActiveFocus()
                else { focusRow = 0; root.forceActiveFocus() }
            }
        }
    }

    // ─── Boot log lines ───────────────────────────────────────────────────────
    property var bootLog: []

    function buildBootLog() {
        var lines = []
        var cpu = "", ram = "", vendor = "", product = "", modules = ""

        try {
            var cpuinfo = readFile("/proc/cpuinfo")
            var cm = cpuinfo.match(/model name\s*:\s*(.+)/)
            if (cm) cpu = cm[1].trim()
        } catch(e) {}

        try {
            var meminfo = readFile("/proc/meminfo")
            var mm = meminfo.match(/MemTotal:\s+(\d+)/)
            if (mm) {
                var kb = parseInt(mm[1])
                ram = kb >= 1048576 ? (kb / 1048576).toFixed(1) + " GB" : Math.round(kb / 1024) + " MB"
            }
        } catch(e) {}

        try {
            vendor  = readFile("/sys/class/dmi/id/sys_vendor").trim()
            product = readFile("/sys/class/dmi/id/product_name").trim()
        } catch(e) {}

        try {
            var mods = readFile("/proc/modules")
            if (mods.length > 0) {
                var modList = mods.split("\n")
                var count = 0
                for (var i = 0; i < modList.length; i++) {
                    if (modList[i].length > 0) count++
                }
                modules = count.toString()
            }
        } catch(e) {}

        lines.push({ s: "OK", m: "Starting " + dispHost + "..." })
        if (vendor.length > 0 && product.length > 0)
            lines.push({ s: "OK", m: "Detected hardware: " + vendor + " " + product })
        lines.push({ s: "OK", m: "Reached target Switch Root." })
        lines.push({ s: "OK", m: "Started Journal Service." })
        lines.push({ s: "OK", m: "Mounted /sys/kernel/security." })
        if (cpu.length > 0)
            lines.push({ s: "OK", m: "CPU: " + cpu })
        if (ram.length > 0)
            lines.push({ s: "OK", m: "Memory: " + ram + " total" })
        if (modules.length > 0)
            lines.push({ s: "OK", m: "Loaded " + modules + " kernel modules." })
        lines.push({ s: "OK", m: "Started Udev Coldplug all Devices." })
        lines.push({ s: "OK", m: "Started Network Manager." })
        lines.push({ s: "OK", m: "Reached target Graphical Interface." })
        lines.push({ s: "OK", m: "Started SDDM Display Manager." })
        lines.push({ s: "OK", m: "Welcome to " + realDistro + "." })

        // Filler when SDDM blocks /proc reads — keeps log from looking empty
        if (cpu.length === 0 && ram.length === 0 && modules.length === 0 && vendor.length === 0) {
            lines.splice(4, 0, { s: "OK", m: "System initialized." })
        }

        bootLog = lines
    }

    // ─── Clock ────────────────────────────────────────────────────────────────
    Text {
        id: clockLabel
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 16; anchors.rightMargin: 20
        font.family: cfgFont; font.pixelSize: 12; color: clockClr
        Component.onCompleted: text = Qt.formatDateTime(new Date(), dateTimeFmt)
        Timer { interval: 10000; running: true; repeat: true
            onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), dateTimeFmt) }
    }
}
