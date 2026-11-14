import QtQuick
import QtQuick.Controls

// The radial menu: cells evenly around the pointer (first on top), folders
// fly the next ring out, the center is Settings on the root and Back inside.
Item {
    id: root

    readonly property real cx: win.cx
    readonly property real cy: win.cy
    readonly property int count: backend.items.length
    // A comfortable gap from the center button; cells shrink when there are
    // many, so neighbors keep a small gap instead of overlapping.
    readonly property real ringRadius: 170
    readonly property int cellSize: count > 0
        ? Math.max(44, Math.min(66, Math.floor(2 * Math.PI * ringRadius / count) - 8))
        : 66
    property int launchingIndex: -1
    property int hoveredIndex: -1
    readonly property real hoveredAngle: hoveredIndex >= 0
        ? -Math.PI / 2 + hoveredIndex * 2 * Math.PI / Math.max(count, 1) : 0
    // The action that runs after the ring has folded away (enter/back/launch).
    property var pendingCall: null
    // The click that opened the overlay must not count as a close-click.
    property real openedAt: 0

    Connections {
        target: backend
        function onPlacementChanged() {
            if (backend.placed)
                root.openedAt = Date.now()
        }
    }

    // Fade the whole overlay in once the compositor has placed the window.
    opacity: backend.placed && !win.closing ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    // Clicking anywhere outside the ring closes, like every launcher.
    MouseArea {
        anchors.fill: parent
        onClicked: (mouse) => {
            if (Date.now() - root.openedAt < 300)
                return
            const dx = mouse.x - root.cx, dy = mouse.y - root.cy
            if (Math.hypot(dx, dy) > root.ringRadius + 70)
                win.closeOrbit()
        }
    }

    function foldAwayThen(call) {
        root.pendingCall = call
        foldAnim.restart()
    }

    SequentialAnimation {
        id: foldAnim
        NumberAnimation { target: ringContent; property: "scale"; to: 0.6; duration: 130; easing.type: Easing.InQuad }
        NumberAnimation { target: ringContent; property: "opacity"; to: 0; duration: 90 }
        ScriptAction { script: { root.pendingCall(); root.pendingCall = null } }
        onFinished: { ringContent.scale = 1; ringContent.opacity = 1 }
    }

    Item {
        id: ringContent
        width: 1; height: 1 // only a container; cells position themselves absolutely
        x: root.cx
        y: root.cy

        // A line from the center to the hovered cell, with a pulse running
        // along it toward the icon.
        Item {
            id: hoverLine
            visible: root.hoveredIndex >= 0
            x: 0
            y: 0
            rotation: root.hoveredAngle * 180 / Math.PI

            Rectangle {
                x: 46
                y: -1
                width: Math.max(0, root.ringRadius - 46)
                height: 2
                opacity: 0.55
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.35; color: theme.accent }
                    GradientStop { position: 1; color: theme.accent }
                }
            }
            Rectangle {
                width: 9; height: 9; radius: 4.5
                y: -4.5
                color: "#ffffff"
                SequentialAnimation on x {
                    running: hoverLine.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 46; to: root.ringRadius - 6; duration: 550; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 120 }
                }
                SequentialAnimation on opacity {
                    running: hoverLine.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 1; duration: 275 }
                    NumberAnimation { from: 1; to: 0.2; duration: 275 }
                    NumberAnimation { from: 0.2; to: 0; duration: 120 }
                    PauseAnimation { duration: 120 }
                }
            }
        }

        // Center button: Settings at the root, Back inside a folder.
        AbstractButton {
            id: center
            width: 88; height: 88
            x: -44; y: -44
            hoverEnabled: true
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onClicked: backend.breadcrumb.length > 1
                        ? root.foldAwayThen(() => { backend.selectBreadcrumb(backend.breadcrumb.length - 2) })
                        : win.openSettingsPage()

            background: Rectangle {
                radius: width / 2
                color: center.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.35)
                border.width: 2
                border.color: theme.accent
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            contentItem: Item {
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: "image://icons/" + (backend.breadcrumb.length > 1 ? "go-previous" : "preferences-system")
                        sourceSize: Qt.size(30, 30)
                        width: 30; height: 30
                        fillMode: Image.PreserveAspectFit
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: backend.breadcrumb.length > 1 ? qsTr("Back") : qsTr("Settings")
                        font.pixelSize: 10
                        color: "#ffffff"
                    }
                }
            }
        }

        // The current folder name under the center, when inside one.
        Label {
            visible: backend.breadcrumb.length > 1
            y: 56
            anchors.horizontalCenter: parent.horizontalCenter
            text: backend.currentName
            font.pixelSize: 12
            font.bold: true
            color: "#ffffff"
        }

        Repeater {
            model: backend.items

            delegate: AbstractButton {
                id: cell

                required property var modelData
                required property int index

                readonly property real angle: -Math.PI / 2 + index * 2 * Math.PI / Math.max(root.count, 1)
                readonly property bool glowing: (cell.hovered || root.launchingIndex === index) && !win.closing

                x: root.ringRadius * Math.cos(angle) - width / 2
                y: root.ringRadius * Math.sin(angle) - height / 2
                width: root.cellSize + 8
                height: root.cellSize + 8
                hoverEnabled: true
                HoverHandler { cursorShape: Qt.PointingHandCursor }

                // Pop-in, staggered like the web orbit (0.34, 1.56, 0.64, 1).
                property real pop: 0
                scale: pop
                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: cell.index * 25 }
                    NumberAnimation { target: cell; property: "pop"; from: 0; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }

                onClicked: {
                    if (modelData.folder) {
                        root.foldAwayThen(() => backend.enter(index))
                    } else {
                        root.launchingIndex = index
                        launchTimer.start()
                    }
                }

                onHoveredChanged: root.hoveredIndex = cell.hovered ? index
                                  : (root.hoveredIndex === index ? -1 : root.hoveredIndex)

                Timer {
                    id: launchTimer
                    interval: 120
                    onTriggered: {
                        backend.launch(cell.index)
                        win.closeOrbit()
                    }
                }

                background: Rectangle {
                    anchors.centerIn: parent
                    width: root.cellSize
                    height: root.cellSize
                    radius: width / 2
                    color: cell.glowing ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.05, 0.05, 0.07, 0.72)
                    border.width: cell.glowing ? 2 : 1
                    border.color: cell.glowing ? theme.accent : Qt.rgba(1, 1, 1, 0.18)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                contentItem: Item {
                    Image {
                        anchors.centerIn: parent
                        source: "image://icons/" + encodeURIComponent(modelData.icon || "application-x-executable")
                        sourceSize: Qt.size(32, 32)
                        width: 32; height: 32
                        fillMode: Image.PreserveAspectFit
                    }
                    // Folder cells get a small count badge on the edge.
                    Rectangle {
                        visible: modelData.folder && modelData.count > 0
                        width: 20; height: 20; radius: 10
                        x: root.cellSize - 18
                        y: root.cellSize - 26
                        color: theme.accent
                        Label {
                            anchors.centerIn: parent
                            text: modelData.count > 9 ? "9+" : modelData.count
                            font.pixelSize: 10
                            font.bold: true
                            color: theme.accentForeground
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.cellSize + 10
                        width: root.cellSize + 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        font.pixelSize: 11
                        color: "#ffffff"
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                    }
                }

                // The "ping" ring on the hovered cell, straight from orbit2.
                Rectangle {
                    visible: cell.hovered && !modelData.folder
                    anchors.centerIn: parent
                    width: root.cellSize; height: root.cellSize
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: theme.accent
                    SequentialAnimation on scale {
                        running: cell.hovered
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 1.55; duration: 900 }
                        NumberAnimation { from: 1; to: 1; duration: 0 }
                    }
                    SequentialAnimation on opacity {
                        running: cell.hovered
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.7; to: 0; duration: 900 }
                        NumberAnimation { from: 1; to: 1; duration: 0 }
                    }
                }
            }
        }
    }
}
