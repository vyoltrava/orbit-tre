import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import qs.Commons
import qs.Commons as Commons

Page {
  id: page

  property var menuRoot: null
  property int selected: -1
  property bool recording: false
  property var recordedMods: []

  Material.theme: Material.Dark
  Material.background: page.menuRoot ? page.menuRoot.menuBackgroundColor : Commons.Color.menu.background
  Material.foreground: page.menuRoot ? page.menuRoot.menuTextColor : Commons.Color.menu.text
  Material.accent: page.menuRoot ? page.menuRoot.menuAccentColor : Commons.Color.accent
  background: null
  focus: visible

  Connections {
    target: page.menuRoot
    function onItemsChanged() {
      if (page.selected >= page.menuRoot.items.length)
        page.selected = page.menuRoot.items.length - 1
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: page.menuRoot.settingsOpen = false
  }

  Rectangle {
    id: panel
    anchors.centerIn: parent
    width: Math.min(780, page.width - 48)
    height: Math.min(680, page.height - 48)
    radius: Math.max(12, Style.cornerRadius)
    color: Material.background
    border.color: page.menuRoot.menuBorderColor

    MouseArea { anchors.fill: parent }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 14

      RowLayout {
        Layout.fillWidth: true
        Label {
          text: page.tr("settings.title")
          font.pixelSize: 18
          font.bold: true
          color: Material.foreground
        }
        Item { Layout.fillWidth: true }
        Button {
          text: page.tr("common.back")
          onClicked: page.menuRoot.settingsOpen = false
          Material.roundedScale: Math.min(4, Style.cornerRadius)
        }
        Button {
          text: page.tr("common.quit")
          onClicked: page.menuRoot.close()
          Material.roundedScale: Math.min(4, Style.cornerRadius)
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Label { text: page.tr("settings.openWith"); color: Material.foreground }
        Rectangle {
          Layout.preferredHeight: 30
          Layout.preferredWidth: comboLabel.implicitWidth + 24
          radius: 8
          color: Qt.rgba(1, 1, 1, 0.06)
          border.color: Material.accent
          Label {
            id: comboLabel
            anchors.centerIn: parent
            text: page.menuRoot.activationCombo
            color: Material.accent
            font.bold: true
          }
        }
        Button {
          text: page.recording ? page.tr("common.cancel") : page.tr("settings.change")
          onClicked: page.recording ? page.stopRecording() : page.startRecording()
          Material.roundedScale: Math.min(4, Style.cornerRadius)
        }
        Label {
          Layout.fillWidth: true
          visible: page.recording
          text: page.tr("settings.recording")
          color: Material.accent
          font.italic: true
        }
      }

      GroupBox {
        Layout.fillWidth: true
        title: page.tr("settings.appearance")

        ColumnLayout {
          anchors.fill: parent
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            Label { text: page.tr("settings.animation"); color: Material.foreground }
            ComboBox {
              Layout.preferredWidth: 180
              model: [
                page.tr("settings.animation.full"),
                page.tr("settings.animation.reduced"),
                page.tr("settings.animation.off")
              ]
              currentIndex: page.menuRoot.animationPreset === "reduced" ? 1
                : page.menuRoot.animationPreset === "off" ? 2 : 0
              onActivated: page.menuRoot.setAnimationPreset(["full", "reduced", "off"][currentIndex])
              Material.roundedScale: Math.min(4, Style.cornerRadius)
            }
            Item { Layout.fillWidth: true }
            CheckBox {
              text: page.tr("settings.showNames")
              checked: page.menuRoot.showNames
              onToggled: page.menuRoot.setShowNames(checked)
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Label { text: page.tr("settings.colors"); color: Material.foreground }
            Repeater {
              model: [
                { key: "background", label: page.tr("settings.color.background") },
                { key: "selectedBackground", label: page.tr("settings.color.selectedBackground") },
                { key: "text", label: page.tr("settings.color.text") },
                { key: "accent", label: page.tr("settings.color.accent") },
                { key: "border", label: page.tr("settings.color.border") }
              ]
              delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2
                Button {
                  Layout.alignment: Qt.AlignHCenter
                  Layout.preferredWidth: 48
                  Layout.preferredHeight: 26
                  onClicked: page.openColorPicker(modelData.key)
                  background: Rectangle {
                    radius: 5
                    color: page.menuRoot.colorForRole(modelData.key)
                    border.width: 1
                    border.color: page.menuRoot.menuTextColor
                  }
                  ToolTip.visible: hovered
                  ToolTip.text: modelData.label
                  Material.roundedScale: Math.min(4, Style.cornerRadius)
                }
                Label {
                  Layout.fillWidth: true
                  text: modelData.label
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  font.pixelSize: 9
                  color: Material.foreground
                }
              }
            }
            Button {
              text: page.tr("settings.resetColors")
              onClicked: page.menuRoot.resetColors()
              Material.roundedScale: Math.min(4, Style.cornerRadius)
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
          model: page.menuRoot.breadcrumb
          delegate: Button {
            required property string modelData
            required property int index
            text: modelData
            flat: index > 0
            font.bold: index === page.menuRoot.breadcrumb.length - 1
            onClicked: page.menuRoot.selectBreadcrumb(index)
            Material.roundedScale: Math.min(4, Style.cornerRadius)
          }
        }
        Item { Layout.fillWidth: true }
        Button {
          text: page.tr("editor.addApp")
          onClicked: appPicker.openFor("add")
          enabled: page.menuRoot.items.length < 12
          Material.roundedScale: Math.min(4, Style.cornerRadius)
        }
        Button {
          text: page.tr("editor.addFolder")
          onClicked: page.menuRoot.addFolder("")
          enabled: page.menuRoot.items.length < 12
          Material.roundedScale: Math.min(4, Style.cornerRadius)
        }
      }

      Label {
        visible: page.menuRoot.items.length === 0
        Layout.fillWidth: true
        text: page.tr("editor.empty")
        color: Qt.rgba(1, 1, 1, 0.5)
      }

      ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        GridView {
          id: grid
          clip: true
          model: page.menuRoot.items
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
            Material.roundedScale: Math.min(4, Style.cornerRadius)

            background: Rectangle {
              radius: 10
              color: page.selected === index ? Qt.alpha(page.menuRoot.menuAccentColor, 0.16)
                                             : Qt.rgba(1, 1, 1, cell.hovered ? 0.08 : 0.03)
              border.width: page.selected === index ? 2 : 1
              border.color: page.selected === index ? page.menuRoot.menuAccentColor : page.menuRoot.menuBorderColor
            }

            contentItem: ColumnLayout {
              spacing: 4
              Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Image {
                  anchors.centerIn: parent
                  source: page.menuRoot.iconSource(cell.modelData.icon)
                  sourceSize: Qt.size(36, 36)
                  width: 36
                  height: 36
                  fillMode: Image.PreserveAspectFit
                }
                Image {
                  visible: cell.modelData.type === "folder"
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  source: page.menuRoot.iconSource("folder")
                  sourceSize: Qt.size(16, 16)
                  width: 16
                  height: 16
                }
              }
              Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: cell.modelData.name
                font.pixelSize: 11
                color: Material.foreground
              }
            }
          }
        }
      }

      GroupBox {
        Layout.fillWidth: true
        visible: page.selected >= 0
        label: Label { text: page.tr("editor.cell"); font.bold: true; color: Material.foreground }
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

          Label { text: page.tr("editor.name"); color: Material.foreground }
          TextField {
            Layout.fillWidth: true
            text: page.selected >= 0 && page.menuRoot.items[page.selected]
              ? page.menuRoot.items[page.selected].name : ""
            onTextEdited: if (page.selected >= 0) page.menuRoot.renameItem(page.selected, text)
            Material.roundedScale: Math.min(4, Style.cornerRadius)
          }

          Label {
            visible: page.selected >= 0 && !!page.menuRoot.items[page.selected]
              && page.menuRoot.items[page.selected].type === "app"
            text: page.tr("editor.command")
            color: Material.foreground
          }
          TextField {
            visible: page.selected >= 0 && !!page.menuRoot.items[page.selected]
              && page.menuRoot.items[page.selected].type === "app"
            Layout.fillWidth: true
            text: page.selected >= 0 && page.menuRoot.items[page.selected]
              ? String(page.menuRoot.items[page.selected].cmd || "") : ""
            onTextEdited: if (page.selected >= 0) page.menuRoot.setCommand(page.selected, text)
            Material.roundedScale: Math.min(4, Style.cornerRadius)
          }

          RowLayout {
            spacing: 6
            Button {
              text: page.tr("editor.openFolder")
              visible: page.selected >= 0 && !!page.menuRoot.items[page.selected]
                && page.menuRoot.items[page.selected].type === "folder"
              onClicked: page.menuRoot.enter(page.selected)
              Material.roundedScale: Math.min(4, Style.cornerRadius)
            }
            Button {
              text: page.tr("editor.chooseIcon")
              onClicked: appPicker.openFor("icon")
              Material.roundedScale: Math.min(4, Style.cornerRadius)
            }
            Button {
              text: "◀"
              enabled: page.selected > 0
              onClicked: { page.menuRoot.moveItem(page.selected, -1); page.selected -= 1 }
              Material.roundedScale: Math.min(4, Style.cornerRadius)
            }
            Button {
              text: "▶"
              enabled: page.selected >= 0 && page.selected < page.menuRoot.items.length - 1
              onClicked: { page.menuRoot.moveItem(page.selected, 1); page.selected += 1 }
              Material.roundedScale: Math.min(4, Style.cornerRadius)
            }
            Button {
              text: page.tr("common.remove")
              enabled: page.selected >= 0
              onClicked: { page.menuRoot.removeItem(page.selected); page.selected = -1 }
              Material.roundedScale: Math.min(4, Style.cornerRadius)
            }
          }
        }
      }

      Label {
        Layout.fillWidth: true
        text: page.tr("editor.help")
        wrapMode: Text.Wrap
        font.pixelSize: 11
        color: Qt.rgba(1, 1, 1, 0.5)
      }
    }
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (page.recording) page.stopRecording()
      else page.menuRoot.settingsOpen = false
      event.accepted = true
      return
    }
    if (!page.recording) return
    var mods = page.modsFrom(event.modifiers)
    var key = page.keyName(event.key)
    if (!key) return
    page.menuRoot.setActivation(mods, key)
    page.stopRecording()
    event.accepted = true
  }

  MouseArea {
    anchors.fill: parent
    enabled: page.recording
    z: 99
    acceptedButtons: Qt.AllButtons
    onPressed: function(mouse) {
      page.menuRoot.setActivation(page.modsFrom(mouse.modifiers), page.buttonName(mouse.button))
      page.stopRecording()
    }
  }

  Popup {
    id: appPicker
    property string purpose: "add"
    property string filter: ""

    function openFor(why) {
      purpose = why
      filter = ""
      search.text = ""
      page.menuRoot.refreshAppIcons()
      open()
      search.forceActiveFocus()
    }

    anchors.centerIn: parent
    width: Math.min(420, page.width - 80)
    height: Math.min(480, page.height - 120)
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
        placeholderText: page.tr("editor.search")
        onTextEdited: appPicker.filter = text
        Material.roundedScale: Math.min(4, Style.cornerRadius)
      }

      ListView {
        id: appList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: page.menuRoot.searchApplications(appPicker.filter)

        delegate: ItemDelegate {
          id: appRow
          required property var modelData
          required property int index
          width: appList.width
          onClicked: {
            if (appPicker.purpose === "add")
              page.menuRoot.addApplication(modelData.id)
            else if (page.selected >= 0)
              page.menuRoot.setIcon(page.selected, modelData.icon)
            appPicker.close()
          }
          Material.roundedScale: Math.min(4, Style.cornerRadius)

          contentItem: RowLayout {
            spacing: 10
            Image {
              source: page.menuRoot.iconSource(appRow.modelData.icon)
              sourceSize: Qt.size(28, 28)
              width: 28
              height: 28
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
          text: page.tr("editor.noResults")
          color: Qt.rgba(1, 1, 1, 0.5)
        }
      }
    }
  }

  ColorDialog {
    id: colorPicker
    property string role: "accent"
    parentWindow: page.Window.window
    modality: Qt.WindowModal
    options: ColorDialog.DontUseNativeDialog
    title: page.tr("settings.chooseColor").arg(page.colorRoleLabel(role))
    onAccepted: page.menuRoot.setColorOverride(role, page.colorToHex(selectedColor))
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function tr(key) {
    return strings.t(key)
  }

  function colorRoleLabel(role) {
    return tr("settings.color." + role)
  }

  function colorToHex(color) {
    function channel(value) {
      var hex = Math.round(value * 255).toString(16)
      return hex.length < 2 ? "0" + hex : hex
    }
    return "#" + channel(color.r) + channel(color.g) + channel(color.b)
  }

  function openColorPicker(role) {
    colorPicker.role = role
    colorPicker.selectedColor = page.menuRoot.colorForRole(role)
    colorPicker.open()
  }

  function startRecording() {
    recording = true
    forceActiveFocus()
  }

  function stopRecording() {
    recording = false
  }

  function modsFrom(modifiers) {
    var result = []
    if (modifiers & Qt.ShiftModifier) result.push("SHIFT")
    if (modifiers & Qt.ControlModifier) result.push("CTRL")
    if (modifiers & Qt.AltModifier) result.push("ALT")
    if (modifiers & Qt.MetaModifier) result.push("SUPER")
    return result
  }

  function keyName(key) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key)
    if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1)
    var names = {}
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
}
