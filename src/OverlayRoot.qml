import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// The radial menu: cells evenly around the pointer (first on top); folders
// fly the next ring out around their own cell while the previous level stays
// on screen behind, frozen and blurred, and climbing back up returns to the
// stored spot.
Item {
    id: root

    // The ring's center in window coordinates: the pointer when the orbit
    // opens, then the clicked folder's cell for a nested orbit. Assigning on
    // navigation replaces the binding on purpose: a fresh overlay starts
    // from the pointer again.
    property real centerX: win.cx
    property real centerY: win.cy
    // Where each level's ring sat, so going up a level returns the ring to
    // the same spot instead of collapsing to the pointer.
    property var levelCenters: []
    readonly property int count: backend.items.length
    // A comfortable gap from the center button; cells shrink when there are
    // many, so neighbors keep a small gap instead of overlapping.
    readonly property real ringRadius: 85
    readonly property int cellSize: count > 0
        ? Math.max(44, Math.min(66, Math.floor(2 * Math.PI * ringRadius / count) - 8))
        : 66
    // Иконка ровно по кругу ячейки: провайдер обрезает её по окружности,
    // поэтому квадратные иконки не выпирают за край, а края честно режутся.
    readonly property int cellIconSize: cellSize
    property int launchingIndex: -1
    property int hoveredIndex: -1
    // The previous level, left on screen behind the active ring: a frozen
    // copy of the ring as it was the moment the folder was clicked, blurred.
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
            const dx = mouse.x - root.centerX, dy = mouse.y - root.centerY
            if (Math.hypot(dx, dy) > root.ringRadius + 35)
                win.closeOrbit()
        }
    }

    // A nested orbit opens around the folder cell that was clicked, clamped
    // so the whole child ring stays on screen — a ring hanging off the edge
    // would turn its far side into "outside" clicks that close the overlay.
    // The ring being left stays exactly where it is, as a blurred copy under
    // the active ring; the click that opened the folder replaces it.
    function enterFolder(index) {
        const depth = backend.breadcrumb.length - 1
        levelCenters[depth] = { x: centerX, y: centerY }
        ghostItems = backend.items
        ghostNested = depth > 0
        ghostX = centerX
        ghostY = centerY
        ghostShown = true
        const angle = -Math.PI / 2 + index * 2 * Math.PI / Math.max(count, 1)
        const margin = ringRadius + 40
        centerX = Math.min(Math.max(centerX + ringRadius * Math.cos(angle), margin), win.width - margin)
        centerY = Math.min(Math.max(centerY + ringRadius * Math.sin(angle), margin), win.height - margin)
        backend.enter(index)
    }

    function leaveFolder() {
        const depth = backend.breadcrumb.length - 1
        ghostShown = false // the returning ring pops in under the fading ghost
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

    // The level just left, parked exactly where it was: a frozen copy of the
    // ring (cells and center), blurred and dimmed under the active ring. It
    // is drawn from a captured copy of the items, so it never follows the
    // live model, and it fades away as the active ring returns to it.
    Item {
        id: ghost
        x: root.ghostX - root.ringRadius - 55
        y: root.ghostY - root.ringRadius - 55
        width: (root.ringRadius + 110) * 2
        height: (root.ringRadius + 110) * 2
        visible: opacity > 0.01
        opacity: root.ghostShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Blurred and slightly dimmed: clearly a layer behind, never a
        // second active menu. The blur comes from a layer, because a
        // MultiEffect that samples a hidden item gets an empty texture.
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

            // Ring origin: the ghost cells are laid out around this point.
            Item {
                x: ghostRing.width / 2
                y: ghostRing.height / 2
                width: 1
                height: 1

                Rectangle {
                    width: 44; height: 44
                    x: -44; y: -44
                    radius: 22
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.width: 1
                    border.color: theme.accent
                    Image {
                        anchors.centerIn: parent
                        source: root.ghostNested ? "image://icons/go-previous" : "qrc:/orbit.svg"
                        sourceSize: Qt.size(42, 42)
                        width: 42; height: 42
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
                            width: 10; height: 10; radius: 5
                            x: root.ghostCellSize - 18
                            y: root.ghostCellSize - 13
                            color: theme.accent
                            Label {
                                anchors.centerIn: parent
                                text: modelData.count > 9 ? "9+" : modelData.count
                                font.pixelSize: 5
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
        width: 1; height: 1 // only a container; cells position themselves absolutely
        x: root.centerX
        y: root.centerY

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
                width: Math.max(0, root.ringRadius - 23)
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
                    NumberAnimation { from: 23; to: root.ringRadius - 3; duration: 550; easing.type: Easing.InOutQuad }
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

        // The center opens Settings at the root and goes back inside a folder.
        AbstractButton {
            id: center
            width: 44; height: 44
            x: -44; y: -44
            hoverEnabled: true
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onClicked: backend.breadcrumb.length > 1
                        ? root.foldAwayThen(() => root.leaveFolder())
                        : win.openSettingsPage()

            background: Rectangle {
                radius: width / 2
                color: center.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.35)
                border.width: 1
                border.color: theme.accent
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            contentItem: Item {
                Image {
                    anchors.centerIn: parent
                    source: backend.breadcrumb.length > 1
                            ? "image://icons/go-previous" : "qrc:/orbit.svg"
                    sourceSize: Qt.size(42, 42)
                    width: 42; height: 42
                    fillMode: Image.PreserveAspectFit
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
                        // No fold: the ring being left stays on screen as the
                        // blurred ghost, the child orbit pops around the cell.
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
                    // Folder cells get a small count badge on the edge.
                    Rectangle {
                        visible: modelData.folder && modelData.count > 0
                        width: 10; height: 10; radius: 5
                        x: root.cellSize - 9
                        y: root.cellSize - 13
                        color: theme.accent
                        Label {
                            anchors.centerIn: parent
                            text: modelData.count > 9 ? "9+" : modelData.count
                            font.pixelSize: 5
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

                // The "ping" ring on the hovered cell, straight from orbit2.
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
