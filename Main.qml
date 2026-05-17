// Echo SDDM Theme — Main.qml
// macOS Terminal aesthetic | xCaptaiN09
//
// Qt 6 + qt6-5compat required (Arch: sudo pacman -S qt6-5compat)
// Qt 5: replace "Qt5Compat.GraphicalEffects" → "QtGraphicalEffects 1.0"
//
// Real sysinfo in test mode: QML_XHR_ALLOW_FILE_READ=1 sddm-greeter-qt6 --test-mode --theme ...

import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Rectangle {
    id: root
    width:  Screen.width
    height: Screen.height
    color:  "#0d0d0d"
    focus:  true

    // ─── Config ───────────────────────────────────────────────────────────────
    property string themeType: config.type        || "pure"    // "pure" | "frosted"
    property string loginMode: config.login_mode  || "select"  // "tty"  | "select"
    property string bgPath:    config.background  || ""
    property string cfgFont:   config.font        || "JetBrains Mono"
    property int    fontSize:  parseInt(config.font_size)     > 0 ? parseInt(config.font_size)     : 14
    property int    bootMs:    parseInt(config.boot_interval) > 0 ? parseInt(config.boot_interval) : 72
    property bool   use24h:    config.use_24h !== "false" && config.use_24h !== "0"  // default true
    property string timeFmt:   use24h ? "HH:mm" : "h:mm AP"

    // ─── Real system info ─────────────────────────────────────────────────────
    property string realDistro: "Arch Linux"
    property string realKernel: "linux"
    property string realUptime: ""

    function readFile(path) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", path, false)
        try { xhr.send() } catch(e) { return "" }
        return xhr.responseText || ""
    }

    function loadSysInfo() {
        var osrel = readFile("/etc/os-release")
        var dm = osrel.match(/PRETTY_NAME="([^"]+)"/)
        if (dm) realDistro = dm[1]

        var ver = readFile("/proc/version")
        var km = ver.match(/Linux version (\S+)/)
        if (km) realKernel = km[1]

        var up = readFile("/proc/uptime")
        var secs = parseFloat(up.split(" ")[0])
        if (!isNaN(secs)) {
            var h = Math.floor(secs / 3600)
            var m = Math.floor((secs % 3600) / 60)
            realUptime = h > 0 ? h + "h " + m + "m" : m + "m"
        }
    }

    Component.onCompleted: { loadSysInfo(); buildBootLog() }

    property string dispHost: sddm.hostName.length > 0 ? sddm.hostName : "localhost"

    // ─── State ────────────────────────────────────────────────────────────────
    property int    bootStep:   0
    property bool   bootDone:   false
    property bool   didFail:    false
    property string failMsg:    ""
    property int    userIdx:    0
    property int    sessIdx:    sessionModel.lastIndex
    property int    ttySession: sessionModel.lastIndex
    property int    focusRow:   0   // 0=user, 1=session, 2=password

    // ─── Helpers ──────────────────────────────────────────────────────────────
    // Fallback data for test mode (models may be empty)
    property var mockUsers:    ["captain", "guest"]
    property var mockSessions: ["hyprland", "hyprland-uwsm"]
    property bool isTestMode:  userModel.rowCount() === 0

    // Hidden Repeaters to access model.name correctly
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

    function userName(i) { if (userRep.count === 0) return mockUsers[i] || "";    var item = userRep.itemAt(i); return item ? item.loginName : "" }
    function sessName(i) { if (sessRep.count === 0) return mockSessions[i] || ""; var item = sessRep.itemAt(i); return item ? item.sessName  : "" }
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
            failMsg = "Login incorrect. Please try again."
            if (loginMode === "tty") {
                ttyPwd.text = ""
                ttyPwd.forceActiveFocus()
            } else {
                pwdInput.text = ""
                pwdInput.forceActiveFocus()
            }
        }
    }

    // ─── F1/F2 session switch (TTY mode) ──────────────────────────────────────
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
                radius: 54
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
            color:        bgImage.visible ? Qt.rgba(0.06, 0.06, 0.06, 0.78) : "#1c1c1e"
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
                color:          "#636368"
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
                    Text { text: "[ ";  font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2" }
                    Text {
                        text:  bootLog[index].s === "OK" ? " OK " : "FAIL"
                        font.family: cfgFont; font.pixelSize: fontSize
                        color: bootLog[index].s === "OK" ? "#4ec94e" : "#e05252"
                    }
                    Text { text: " ] " + bootLog[index].m; font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2" }
                }
            }

            Item { width: 1; height: 14; visible: bootDone }

            // Sysinfo
            Text {
                id: sysInfo
                visible: bootDone
                opacity: 0.0
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2"
                property string curTime: Qt.formatTime(new Date(), timeFmt)
                text: dispHost + "  |  " + realDistro + "  |  " + realKernel
                    + (realUptime.length > 0 ? "  |  up " + realUptime : "")
                    + "  |  " + curTime
                Timer { interval: 30000; running: true; repeat: true
                    onTriggered: sysInfo.curTime = Qt.formatTime(new Date(), "HH:mm") }
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
                    Text { text: dispHost + " login: "; font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2" }
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
                        width: 9; height: fontSize + 3; color: "#bebec2"
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
                    Text { text: "Password: "; font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2" }
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
                        width: 9; height: fontSize + 3; color: "#bebec2"
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

                Item { width: 1; height: 10 }
                Row {
                    spacing: 0
                    Text { text: "[F1] [F2] session: "; font.family: cfgFont; font.pixelSize: fontSize - 1; color: "#444448" }
                    Text { text: sessName(ttySession); font.family: cfgFont; font.pixelSize: fontSize - 1; color: "#636368" }
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
                    Text { text: "user:     "; font.family: cfgFont; font.pixelSize: fontSize; color: "#e8a041" }
                    Text { text: userName(userIdx); font.family: cfgFont; font.pixelSize: fontSize; color: "#e8a041" }
                    Text {
                        text: "  ◀ ▶"; font.family: cfgFont; font.pixelSize: fontSize
                        color: focusRow === 0 ? "#e8a041" : "#444448"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                Row {
                    spacing: 0
                    Text { text: "session:  "; font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2" }
                    Text { text: sessName(sessIdx); font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2" }
                    Text {
                        text: "  ◀ ▶"; font.family: cfgFont; font.pixelSize: fontSize
                        color: focusRow === 1 ? "#bebec2" : "#444448"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                Row {
                    spacing: 0
                    Text { text: "password: "; font.family: cfgFont; font.pixelSize: fontSize; color: "#bebec2" }
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
                        width: 9; height: fontSize + 3; color: "#bebec2"
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
            }

            Item { width: 1; height: 20; visible: bootDone }

            // Error
            Item {
                visible: bootDone
                width:   termCol.width
                height:  didFail ? errText.implicitHeight + 4 : 0
                clip: true
                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Text {
                    id: errText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: failMsg; font.family: cfgFont; font.pixelSize: fontSize; color: "#e8853a"
                    opacity: didFail ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }

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

    // ─── Boot log lines (generated from real system data) ─────────────────────
    property var bootLog: []

    function buildBootLog() {
        var lines = []
        var cpu = "", ram = "", vendor = "", product = "", modules = ""

        // CPU model
        var cpuinfo = readFile("/proc/cpuinfo")
        var cm = cpuinfo.match(/model name\s*:\s*(.+)/)
        if (cm) cpu = cm[1].trim()

        // RAM
        var meminfo = readFile("/proc/meminfo")
        var mm = meminfo.match(/MemTotal:\s+(\d+)/)
        if (mm) {
            var kb = parseInt(mm[1])
            ram = kb >= 1048576 ? (kb / 1048576).toFixed(1) + " GB" : Math.round(kb / 1024) + " MB"
        }

        // Hardware vendor/product
        vendor  = readFile("/sys/class/dmi/id/sys_vendor").trim()
        product = readFile("/sys/class/dmi/id/product_name").trim()

        // Module count
        var mods = readFile("/proc/modules")
        if (mods.length > 0) modules = mods.split("\n").filter(function(l) { return l.length > 0 }).length.toString()

        // Build lines
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
        bootLog = lines
    }

    // ─── Clock ────────────────────────────────────────────────────────────────
    Text {
        id: clockLabel
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 16; anchors.rightMargin: 20
        font.family: cfgFont; font.pixelSize: 12; color: "#3e3e42"
        Component.onCompleted: text = Qt.formatTime(new Date(), timeFmt)
        Timer { interval: 10000; running: true; repeat: true
            onTriggered: clockLabel.text = Qt.formatTime(new Date(), timeFmt) }
    }
}
