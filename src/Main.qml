import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One fullscreen transparent overlay per activation. The menu ring sits
// where the pointer was; clicks outside the ring close it, like any launcher.
ApplicationWindow {
    id: win

    visible: false // main.cpp shows it once the compositor has placed it
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "orbit"
    width: backend.monitorWidth
    height: backend.monitorHeight

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    // The menu center, in window coordinates.
    readonly property real cx: backend.cursorX
    readonly property real cy: backend.cursorY
    property string mode: "orbit" // "orbit" | "settings"
    property bool closing: false

    function openSettingsPage() {
        mode = "settings"
    }

    function closeOrbit() {
        if (closing)
            return
        closing = true
        fadeOut.start()
    }

    ParallelAnimation {
        id: fadeOut
        NumberAnimation { target: overlayRoot; property: "opacity"; to: 0; duration: 140 }
        onFinished: backend.quitApp()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: mode === "settings" ? win.mode = "orbit" : win.closeOrbit()
    }

    OverlayRoot {
        id: overlayRoot
        anchors.fill: parent
        visible: mode === "orbit"
    }

    SettingsPage {
        id: settingsPage
        anchors.fill: parent
        visible: mode === "settings"
        opacity: mode === "settings" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
}
