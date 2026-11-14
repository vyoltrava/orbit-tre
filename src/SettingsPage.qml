import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Settings lives in the center of the ring: edit the menu (folders nest like
// the orbit itself), pick installed applications, set the activation hotkey.
Page {
    id: page

    property int selected: -1
    property bool recording: false
    property var recordedMods: []

    // The menu tree changes under the editor; keep the selection in range.
    Connections {
        target: backend
        function onItemsChanged() {
            if (page.selected >= backend.items.length)
                page.selected = backend.items.length - 1
        }
    }

    background: null

    // Dim behind the panel; a click out here returns to the orbit.
    MouseArea {
        anchors.fill: parent
        onClicked: win.mode = "orbit"
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(780, win.width - 48)
        height: Math.min(680, win.height - 48)
        radius: Math.max(12, theme.radius)
        color: Material.background
        border.color: Qt.rgba(1, 1, 1, 0.12)

        // The panel swallows clicks so the dim layer behind them doesn't
        // throw the user back to the orbit mid-edit.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Orbit settings")
                    font.pixelSize: 18
                    font.bold: true
                    color: Material.foreground
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("To the menu")
                    onClicked: win.mode = "orbit"
                    Material.roundedScale: Math.min(4, theme.radius)
                }
                Button {
                    text: qsTr("Quit")
                    onClicked: backend.quitApp()
                    Material.roundedScale: Math.min(4, theme.radius)
                }
            }

            // ── Activation hotkey ─────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Label {
                    text: qsTr("Open with:")
                    color: Material.foreground
                }
                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: comboLabel.implicitWidth + 24
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: theme.accent
                    Label {
                        id: comboLabel
                        anchors.centerIn: parent
                        text: backend.activationCombo
                        color: theme.accent
                        font.bold: true
                    }
                }
                Button {
                    text: page.recording ? qsTr("Cancel") : qsTr("Change")
                    onClicked: page.recording ? page.stopRecording() : page.startRecording()
                    Material.roundedScale: Math.min(4, theme.radius)
                }
                Label {
                    Layout.fillWidth: true
                    visible: page.recording
                    text: qsTr("Press the combination… (Esc to cancel)")
                    color: theme.accent
                    font.italic: true
                }
            }

            // ── Menu editor ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: backend.breadcrumb
                    delegate: Button {
                        required property string modelData
                        required property int index
                        text: modelData
                        flat: index > 0
                        font.bold: index === backend.breadcrumb.length - 1
                        onClicked: backend.selectBreadcrumb(index)
                        Material.roundedScale: Math.min(4, theme.radius)
                    }
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("+ App")
                    onClicked: appPicker.openFor("add")
                    enabled: backend.items.length < 12
                    Material.roundedScale: Math.min(4, theme.radius)
                }
                Button {
                    text: qsTr("+ Folder")
                    onClicked: backend.addFolder("")
                    enabled: backend.items.length < 12
                    Material.roundedScale: Math.min(4, theme.radius)
                }
            }

            Label {
                visible: backend.items.length === 0
                Layout.fillWidth: true
                text: qsTr("Empty folder — add an app or a folder above.")
                color: Qt.rgba(1, 1, 1, 0.5)
            }

            // Cells of the current folder.
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                GridView {
                    id: grid
                    clip: true
                    model: backend.items
                    cellWidth: 96
                    cellHeight: 104
                    currentIndex: page.selected

                    delegate: ItemDelegate {
                        id: cell
                        required property var modelData
                        required property int index
                        width: grid.cellWidth - 8
                        height: grid.cellHeight - 8
                        onClicked: page.selected = index
                        Material.roundedScale: Math.min(4, theme.radius)

                        background: Rectangle {
                            radius: 10
                            color: page.selected === index ? Qt.alpha(theme.accent, 0.16)
                                                           : Qt.rgba(1, 1, 1, cell.hovered ? 0.08 : 0.03)
                            border.width: page.selected === index ? 2 : 1
                            border.color: page.selected === index ? theme.accent : Qt.rgba(1, 1, 1, 0.10)
                        }

                        contentItem: ColumnLayout {
                            spacing: 4
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                Image {
                                    anchors.centerIn: parent
                                    source: "image://icons/" + encodeURIComponent(modelData.icon || "application-x-executable")
                                    sourceSize: Qt.size(36, 36)
                                    width: 36; height: 36
                                    fillMode: Image.PreserveAspectFit
                                }
                                // Folder badge: opens a nested orbit.
                                Image {
                                    visible: modelData.folder
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    source: "image://icons/" + encodeURIComponent("folder")
                                    sourceSize: Qt.size(16, 16)
                                    width: 16; height: 16
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: modelData.name
                                font.pixelSize: 11
                                color: Material.foreground
                            }
                        }
                    }
                }
            }

            // ── Selected item editor ──────────────────────────────────
            GroupBox {
                Layout.fillWidth: true
                visible: page.selected >= 0
                label: Label { text: qsTr("Cell"); font.bold: true; color: Material.foreground }
                background: Rectangle {
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 8
                    width: parent.width

                    Label { text: qsTr("Name:"); color: Material.foreground }
                    TextField {
                        Layout.fillWidth: true
                        text: (page.selected >= 0 && backend.items[page.selected]) ? backend.items[page.selected].name : ""
                        onTextEdited: if (page.selected >= 0) backend.renameItem(page.selected, text)
                        Material.roundedScale: Math.min(4, theme.radius)
                    }

                    Label {
                        visible: page.selected >= 0 && backend.items[page.selected] && backend.items[page.selected].type === "app"
                        text: qsTr("Command:"); color: Material.foreground
                    }
                    TextField {
                        visible: page.selected >= 0 && backend.items[page.selected] && backend.items[page.selected].type === "app"
                        Layout.fillWidth: true
                        text: (page.selected >= 0 && backend.items[page.selected]) ? backend.items[page.selected].cmd : ""
                        onTextEdited: if (page.selected >= 0) backend.setCommand(page.selected, text)
                        Material.roundedScale: Math.min(4, theme.radius)
                    }

                    RowLayout {
                        spacing: 6
                        Button {
                            text: qsTr("Icon from apps")
                            onClicked: appPicker.openFor("icon")
                            Material.roundedScale: Math.min(4, theme.radius)
                        }
                        Button {
                            text: qsTr("◀")
                            enabled: page.selected > 0
                            onClicked: { backend.moveItem(page.selected, -1); page.selected -= 1 }
                            Material.roundedScale: Math.min(4, theme.radius)
                        }
                        Button {
                            text: qsTr("▶")
                            enabled: page.selected >= 0 && page.selected < backend.items.length - 1
                            onClicked: { backend.moveItem(page.selected, 1); page.selected += 1 }
                            Material.roundedScale: Math.min(4, theme.radius)
                        }
                        Button {
                            text: qsTr("Remove")
                            enabled: page.selected >= 0
                            onClicked: { backend.removeItem(page.selected); page.selected = -1 }
                            Material.roundedScale: Math.min(4, theme.radius)
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("A cell is a link to an app or a folder. Clicking a folder opens its own orbit — nest as deep as you like.")
                wrapMode: Text.Wrap
                font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.5)
            }
        }
    }

    // Recording the activation combo: catch the next key or mouse button.
    Keys.onPressed: (event) => {
        if (!page.recording)
            return
        if (event.key === Qt.Key_Escape) { page.stopRecording(); event.accepted = true; return }
        const mods = page.modsFrom(event.modifiers)
        const key = page.keyName(event.key)
        if (!key)
            return // a bare modifier press — keep waiting
        backend.setActivation(mods, key)
        page.stopRecording()
        event.accepted = true
    }

    // Mouse clicks win over the panel content while recording.
    MouseArea {
        anchors.fill: parent
        enabled: page.recording
        z: 99
        acceptedButtons: Qt.AllButtons
        onPressed: (mouse) => {
            const mods = page.modsFrom(0)
            backend.setActivation(mods, page.buttonName(mouse.button))
            page.stopRecording()
        }
    }

    function startRecording() {
        page.recording = true
        page.forceActiveFocus()
    }
    function stopRecording() {
        page.recording = false
    }

    function modsFrom(m) {
        const list = []
        if (m & Qt.ShiftModifier) list.push("SHIFT")
        if (m & Qt.ControlModifier) list.push("CTRL")
        if (m & Qt.AltModifier) list.push("ALT")
        if (m & Qt.MetaModifier) list.push("SUPER")
        return list
    }

    function keyName(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1)
        const names = {}
        names[Qt.Key_Space] = "SPACE"
        names[Qt.Key_Return] = "RETURN"
        names[Qt.Key_Enter] = "RETURN"
        names[Qt.Key_Tab] = "TAB"
        names[Qt.Key_Backspace] = "BACKSPACE"
        names[Qt.Key_Left] = "LEFT"
        names[Qt.Key_Right] = "RIGHT"
        names[Qt.Key_Up] = "UP"
        names[Qt.Key_Down] = "DOWN"
        names[Qt.Key_Home] = "HOME"
        names[Qt.Key_End] = "END"
        names[Qt.Key_PageUp] = "PRIOR"
        names[Qt.Key_PageDown] = "NEXT"
        names[Qt.Key_Period] = "PERIOD"
        names[Qt.Key_Comma] = "COMMA"
        names[Qt.Key_Minus] = "MINUS"
        names[Qt.Key_Equal] = "EQUAL"
        names[Qt.Key_Slash] = "SLASH"
        names[Qt.Key_Backslash] = "BACKSLASH"
        names[Qt.Key_Semicolon] = "SEMICOLON"
        names[Qt.Key_Apostrophe] = "APOSTROPHE"
        names[Qt.Key_BracketLeft] = "BRACKETLEFT"
        names[Qt.Key_BracketRight] = "BRACKETRIGHT"
        return names[key] || ""
    }

    function buttonName(button) {
        if (button === Qt.LeftButton) return "mouse:272"
        if (button === Qt.RightButton) return "mouse:273"
        if (button === Qt.MiddleButton) return "mouse:274"
        if (button === Qt.BackButton) return "mouse:275"
        if (button === Qt.ForwardButton) return "mouse:276"
        return ""
    }

    // Pick an installed application, either to add a cell or to borrow an icon.
    Popup {
        id: appPicker

        property string purpose: "add" // "add" | "icon"
        property string filter: ""

        function openFor(why) {
            purpose = why
            filter = ""
            search.text = ""
            page.selected = page.selected
            open()
            search.forceActiveFocus()
        }

        anchors.centerIn: parent
        width: Math.min(420, win.width - 80)
        height: Math.min(480, win.height - 120)
        modal: true
        padding: 12
        background: Rectangle {
            radius: 12
            color: Material.background
            border.color: Qt.rgba(1, 1, 1, 0.14)
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            TextField {
                id: search
                Layout.fillWidth: true
                placeholderText: qsTr("Search applications…")
                onTextEdited: appPicker.filter = text
                Material.roundedScale: Math.min(4, theme.radius)
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: backend.searchApplications(appPicker.filter)

                delegate: ItemDelegate {
                    id: appRow
                    required property var modelData
                    required property int index
                    width: appList.width
                    onClicked: {
                        if (appPicker.purpose === "add")
                            backend.addApplication(modelData.id)
                        else if (page.selected >= 0)
                            backend.setIcon(page.selected, modelData.icon)
                        appPicker.close()
                    }
                    Material.roundedScale: Math.min(4, theme.radius)

                    contentItem: RowLayout {
                        spacing: 10
                        Image {
                            source: "image://icons/" + encodeURIComponent(modelData.icon || "application-x-executable")
                            sourceSize: Qt.size(28, 28)
                            width: 28; height: 28
                            fillMode: Image.PreserveAspectFit
                        }
                        Label {
                            Layout.fillWidth: true
                            text: appRow.modelData.name
                            elide: Text.ElideRight
                            color: Material.foreground
                        }
                        Label {
                            text: appRow.modelData.id
                            font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.4)
                            elide: Text.ElideMiddle
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: appList.count === 0
                    text: qsTr("Nothing found")
                    color: Qt.rgba(1, 1, 1, 0.5)
                }
            }
        }
    }
}
