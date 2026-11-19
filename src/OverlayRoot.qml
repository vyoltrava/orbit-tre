import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root

    property real centerX: win.cx
    property real centerY: win.cy
    property var levelCenters: []
    readonly property int count: backend.items.length
    readonly property real ringRadius: 150
    readonly property int cellSize: count > 0
        ? Math.max(44, Math.min(66, Math.floor(2 * Math.PI * ringRadius / count) - 8))
        : 66
    readonly property int cellIconSize: cellSize
    property int launchingIndex: -1
    property int hoveredIndex: -1
    property var ghostItems: []
    property bool ghostNested: false
    property real ghostX: 0
    property real ghostY: 0
    property bool ghostShown: false
    readonly property int ghostCellSize: ghostItems.length > 0
        ? Math.max(44, Math.min(66, Math.floor(2 * Math.PI * ringRadius / ghostItems.length) - 8))
        : 66
    readonly property real hoveredAngle: hoveredIndex >= 0
        ? -Math.PI / 2 + hoveredIndex * 2 * Math.PI / Math.max(count, 1) : 0
    property var pendingCall: null
    property real openedAt: 0

    Connections {
        target: backend
        function onPlacementChanged() {
            if (backend.placed)
                root.openedAt = Date.now()
        }
    }

    opacity: backend.placed && !win.closing ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    MouseArea {
        anchors.fill: parent
        onClicked: (mouse) => {
            if (Date.now() - root.openedAt < 300)
                return
            const dx = mouse.x - root.centerX, dy = mouse.y - root.centerY
            if (Math.hypot(dx, dy) > root.ringRadius + 45)
                win.closeOrbit()
        }
    }

    function enterFolder(index) {
        const depth = backend.breadcrumb.length - 1
        levelCenters[depth] = { x: centerX, y: centerY }
        ghostItems = backend.items
        ghostNested = depth > 0
        ghostX = centerX
        ghostY = centerY
        ghostShown = true
        const angle = -Math.PI / 2 + index * 2 * Math.PI / Math.max(count, 1)
        const margin = ringRadius + 60
        centerX = Math.min(Math.max(centerX + ringRadius * Math.cos(angle), margin), win.width - margin)
        centerY = Math.min(Math.max(centerY + ringRadius * Math.sin(angle), margin), win.height - margin)
        backend.enter(index)
    }

    function leaveFolder() {
        const depth = backend.breadcrumb.length - 1
        ghostShown = false
        if (depth > 0 && levelCenters[depth - 1]) {
            centerX = levelCenters[depth - 1].x
            centerY = levelCenters[depth - 1].y
        }
        backend.selectBreadcrumb(backend.breadcrumb.length - 2)
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
        id: ghost
        x: root.ghostX - root.ringRadius - 70
        y: root.ghostY - root.ringRadius - 70
        width: (root.ringRadius + 140) * 2
        height: (root.ringRadius + 140) * 2
        visible: opacity > 0.01
        opacity: root.ghostShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Item {
            id: ghostRing
            anchors.fill: parent
            opacity: 0.45
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 48
                blur: 1.0
                saturation: -0.35
                brightness: -0.3
            }

            Item {
                x: ghostRing.width / 2
                y: ghostRing.height / 2
                width: 1
                height: 1

                Rectangle {
                    width: 56; height: 56
                    x: -28; y: -28
                    radius: 28
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: theme.accent
                    Image {
                        anchors.centerIn: parent
                        source: root.ghostNested ? "image://icons/go-previous" : "qrc:/orbit.svg"
                        sourceSize: Qt.size(54, 54)
                        width: 54; height: 54
                        fillMode: Image.PreserveAspectFit
                    }
                }

                Repeater {
                    model: root.ghostItems

                    delegate: Item {
                        required property var modelData
                        required property int index

                        readonly property real angle: -Math.PI / 2 + index * 2 * Math.PI / Math.max(root.ghostItems.length, 1)

                        x: root.ringRadius * Math.cos(angle) - width / 2
                        y: root.ringRadius * Math.sin(angle) - height / 2
                        width: root.ghostCellSize + 8
                        height: root.ghostCellSize + 8

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.ghostCellSize
                            height: root.ghostCellSize
                            radius: width / 2
                            color: Qt.rgba(0.05, 0.05, 0.07, 0.72)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)
                        }
                        Image {
                            anchors.centerIn: parent
                            width: root.ghostCellSize
                            height: root.ghostCellSize
                            sourceSize: Qt.size(root.ghostCellSize, root.ghostCellSize)
                            source: "image://icons/circle:" + encodeURIComponent(modelData.icon || "application-x-executable")
                            fillMode: Image.PreserveAspectFit
                        }
                        Rectangle {
                            visible: modelData.folder && modelData.count > 0
                            width: 16; height: 16; radius: 8
                            x: root.ghostCellSize - 14
                            y: root.ghostCellSize - 14
                            color: theme.accent
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.6)
                            Label {
                                anchors.centerIn: parent
                                text: modelData.count > 9 ? "9+" : modelData.count
                                font.pixelSize: 9
                                font.bold: true
                                color: theme.accentForeground
                            }
                        }
                        Label {
                            visible: backend.showNames
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.ghostCellSize + 10
                            width: root.ghostCellSize + 16
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: modelData.name
                            font.pixelSize: 11
                            color: "#ffffff"
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.55)
                        }
                    }
                }
            }
        }
    }

    Item {
        id: ringContent
        width: 1; height: 1
        x: root.centerX
        y: root.centerY

        Item {
            id: hoverLine
            visible: root.hoveredIndex >= 0
            x: 0
            y: 0
            rotation: root.hoveredAngle * 180 / Math.PI

            Rectangle {
                x: 32
                y: -1
                width: Math.max(0, root.ringRadius - root.cellSize / 2 - 32)
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
                    NumberAnimation { from: 32; to: root.ringRadius - root.cellSize / 2 + 8; duration: 550; easing.type: Easing.InOutQuad }
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

        AbstractButton {
            id: center
            width: 56; height: 56
            x: -width / 2
            y: -height / 2
            hoverEnabled: true
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onClicked: backend.breadcrumb.length > 1
                        ? root.foldAwayThen(() => root.leaveFolder())
                        : win.openSettingsPage()

            background: Rectangle {
                radius: width / 2
                color: center.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.55)
                border.width: 2
                border.color: theme.accent
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            contentItem: Item {
                Image {
                    anchors.centerIn: parent
                    source: backend.breadcrumb.length > 1
                            ? "image://icons/go-previous" : "qrc:/orbit.svg"
                    sourceSize: Qt.size(54, 54)
                    width: 54; height: 54
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        // Название текущей папки — над центром, чтобы не наезжать на нижнюю ячейку.
        Label {
            visible: backend.breadcrumb.length > 1
            y: 40
            anchors.horizontalCenter: parent.horizontalCenter
            text: backend.currentName
            font.pixelSize: 13
            font.bold: true
            color: "#ffffff"
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.9)
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

                property real pop: 0
                scale: pop
                SequentialAnimation {
                    running: true
                    PauseAnimation { duration: cell.index * 25 }
                    NumberAnimation { target: cell; property: "pop"; from: 0; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }

                onClicked: {
                    if (modelData.folder) {
                        root.enterFolder(index)
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
                        width: root.cellIconSize
                        height: root.cellIconSize
                        sourceSize: Qt.size(root.cellIconSize, root.cellIconSize)
                        source: "image://icons/circle:" + encodeURIComponent(modelData.icon || "application-x-executable")
                        fillMode: Image.PreserveAspectFit
                    }
                    Rectangle {
                        visible: modelData.folder && modelData.count > 0
                        width: 16; height: 16; radius: 8
                        x: root.cellSize - 14
                        y: root.cellSize - 14
                        color: theme.accent
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.6)
                        Label {
                            anchors.centerIn: parent
                            text: modelData.count > 9 ? "9+" : modelData.count
                            font.pixelSize: 9
                            font.bold: true
                            color: theme.accentForeground
                        }
                    }
                    Label {
                        visible: backend.showNames
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.cellSize + 10
                        width: root.cellSize + 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        font.pixelSize: 11
                        color: "#ffffff"
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                    }
                }

                Rectangle {
                    visible: cell.hovered && !modelData.folder
                    anchors.centerIn: parent
                    width: root.cellSize; height: root.cellSize
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
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