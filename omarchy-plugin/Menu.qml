pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool settingsOpen: false
  // Когда omarchy устанавливает opened = true (shell toggle), инициализируем и показываем оверлей.
  onOpenedChanged: {
    if (opened && !closing && !_opening) {
      _opening = true
      open()
      _opening = false
    }
  }
  property int selectedIndex: 0
  property int hoveredIndex: -1
  property int launchingIndex: -1
  property bool closing: false
  property var pendingCall: null
  property var pendingLaunchNode: null
  property var path: []
  property var menuTree: []
  property string bindingText: ""
  property bool bindingsReady: false
  property var activationMods: ["SHIFT"]
  property string activationKey: "mouse:272"
  property bool showNames: true
  property string animationPreset: "full"
  property var colorOverrides: ({})
  property real cursorGlobalX: 0
  property real cursorGlobalY: 0
  property real monitorX: 0
  property real monitorY: 0
  property bool cursorPositionKnown: false
  property double openedAt: 0
  property bool _opening: false
  readonly property string menuPath: Quickshell.env("HOME") + "/.config/orbit/menu.json"
  readonly property string activationPath: Quickshell.env("HOME") + "/.config/orbit/config.json"
  readonly property string bindingsPath: Quickshell.env("HOME") + "/.config/hypr/bindings.lua"
  readonly property var items: Model.itemsAt(menuTree, path)
  readonly property var currentItems: items
  readonly property string activationCombo: activationMods.concat([activationKey]).join(" + ")
  readonly property string currentName: {
    var branch = Model.itemsAt(menuTree, path.slice(0, -1))
    var parent = branch.length > path[path.length - 1] ? branch[path[path.length - 1]] : null
    return parent ? parent.name : ""
  }
  readonly property real hoveredAngle: hoveredIndex >= 0
    ? -Math.PI / 2 + hoveredIndex * 2 * Math.PI / Math.max(currentItems.length, 1) : 0
  readonly property var breadcrumb: {
    var result = [strings.t("menu.root")]
    var branch = menuTree
    for (var i = 0; i < path.length; i++) {
      var index = Number(path[i])
      if (index < 0 || index >= branch.length) break
      result.push(branch[index].name)
      branch = branch[index].children || []
    }
    return result
  }
  readonly property real centerX: cursorPositionKnown ? cursorGlobalX - monitorX : overlay.width / 2
  readonly property real centerY: cursorPositionKnown ? cursorGlobalY - monitorY : overlay.height / 2
  readonly property int ringRadius: Math.max(100, Math.min(180, Math.min(overlay.width, overlay.height) * 0.30))
  readonly property real sizeScale: 0.6
  readonly property real orbitRadius: ringRadius * sizeScale
  readonly property real centerSize: 88 * sizeScale
  readonly property real centerIconSize: 42 * sizeScale
  readonly property real cellIconSize: 34 * sizeScale
  readonly property real badgeSize: 20 * sizeScale
  readonly property real sparkSize: 9 * sizeScale
  readonly property real cellSize: (currentItems.length > 0
    ? Math.max(44, Math.min(66, Math.floor(2 * Math.PI * ringRadius / currentItems.length) - 8))
    : 66) * sizeScale
  readonly property color menuBackgroundColor: colorForRole("background")
  readonly property color selectedBackgroundColor: colorForRole("selectedBackground")
  readonly property color menuTextColor: colorForRole("text")
  readonly property color menuAccentColor: colorForRole("accent")
  readonly property color menuBorderColor: colorForRole("border")
  readonly property bool motionEnabled: animationPreset !== "off" && Style.duration(1) > 0

  function validColor(value) {
    return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)
  }

  function colorForRole(role) {
    var defaults = {
      background: Commons.Color.menu.background,
      selectedBackground: Commons.Color.menu.selectedBackground,
      text: Commons.Color.menu.text,
      accent: Commons.Color.accent,
      border: Commons.Color.menu.border
    }
    return validColor(colorOverrides[role]) ? colorOverrides[role] : defaults[role]
  }

  function motionDuration(milliseconds) {
    if (animationPreset === "off") return 0
    var duration = animationPreset === "reduced" ? Math.round(milliseconds * 0.5) : milliseconds
    return Style.duration(duration)
  }

  function saveSettings() {
    activationFile.setText(JSON.stringify({
      mods: activationMods,
      key: activationKey,
      settings: {
        showNames: showNames,
        animation: animationPreset,
        colors: colorOverrides
      }
    }, null, 2) + "\n")
  }

  function setShowNames(value) {
    showNames = Boolean(value)
    saveSettings()
  }

  function setAnimationPreset(value) {
    if (["full", "reduced", "off"].indexOf(String(value)) < 0) return
    animationPreset = String(value)
    saveSettings()
  }

  function setColorOverride(role, value) {
    if (["background", "selectedBackground", "text", "accent", "border"].indexOf(String(role)) < 0
        || !validColor(value)) return
    var next = {}
    for (var key in colorOverrides) next[key] = colorOverrides[key]
    next[role] = String(value).toLowerCase()
    colorOverrides = next
    saveSettings()
  }

  function resetColors() {
    colorOverrides = {}
    saveSettings()
  }

  function defaultMenu() {
    var entries = DesktopEntries.applications.values || []
    return Model.defaultItems(entries, shell ? shell.appLibrary : null)
  }

  function loadMenu(raw) {
    var parsed = null
    try { parsed = JSON.parse(String(raw || "")) } catch (e) {
      console.warn("Orbit: cannot parse " + menuPath + ": " + e)
    }
    var next = parsed && parsed.items ? Model.normalizedItems(parsed.items) : []
    menuTree = next.length > 0 ? next : defaultMenu()
    if (selectedIndex >= currentItems.length) selectedIndex = Math.max(0, currentItems.length - 1)
  }

  function saveMenu() {
    menuFile.setText(JSON.stringify({ items: menuTree }, null, 2) + "\n")
  }

  function replaceCurrentItems(next) {
    menuTree = Model.replaceArrayAt(menuTree, path, next)
    saveMenu()
  }

  function updateItem(index, change) {
    var nextTree = Model.normalizedItems(menuTree)
    var current = Model.itemsAt(nextTree, path)
    if (index < 0 || index >= current.length) return
    change(current[index])
    replaceCurrentItems(current)
  }

  function searchApplications(filter) {
    var library = shell ? shell.appLibrary : null
    if (!library) return []
    var entries = Model.entriesFromSearchResults(library.sortedEntries(String(filter || "")))
    var result = []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      result.push({
        id: String(entry.id || ""),
        name: library.entryName(entry) || entry.name || String(entry.id || ""),
        icon: String(entry.icon || "application-x-executable"),
        cmd: String(entry.execString || (entry.command || []).map(function(word) {
          return Util.shellQuote(String(word))
        }).join(" "))
      })
    }
    return result
  }

  function refreshAppIcons() {
    if (shell && shell.appLibrary) shell.appLibrary.refreshIcons()
  }

  function addApplication(desktopId) {
    if (currentItems.length >= Model.maxItems) return
    var apps = searchApplications("")
    for (var i = 0; i < apps.length; i++) {
      if (apps[i].id !== String(desktopId)) continue
      var next = Model.normalizedItems(currentItems)
      next.push({
        type: "app",
        name: apps[i].name,
        icon: apps[i].icon,
        cmd: apps[i].cmd,
        desktopId: apps[i].id
      })
      replaceCurrentItems(next)
      return
    }
  }

  function addFolder(name) {
    if (currentItems.length >= Model.maxItems) return
    var next = Model.normalizedItems(currentItems)
    next.push({
      type: "folder",
      name: String(name || "").trim() || strings.t("item.folder"),
      icon: "folder",
      children: []
    })
    replaceCurrentItems(next)
  }

  function enter(index) {
    if (index < 0 || index >= currentItems.length || currentItems[index].type !== "folder") return
    path = path.concat([index])
    selectedIndex = -1
  }

  function selectBreadcrumb(level) {
    if (level < 0 || level > path.length) return
    path = path.slice(0, level)
    selectedIndex = -1
  }

  function renameItem(index, name) {
    updateItem(index, function(item) { item.name = String(name).slice(0, Model.maxNameLength) })
  }

  function setCommand(index, command) {
    updateItem(index, function(item) {
      item.cmd = String(command).slice(0, Model.maxCommandLength)
      delete item.desktopId
    })
  }

  function setIcon(index, icon) {
    updateItem(index, function(item) { item.icon = String(icon).slice(0, Model.maxIconLength) })
  }

  function removeItem(index) {
    if (index < 0 || index >= currentItems.length) return
    var next = Model.normalizedItems(currentItems)
    next.splice(index, 1)
    replaceCurrentItems(next)
  }

  function moveItem(index, delta) {
    var target = index + delta
    if (index < 0 || index >= currentItems.length || target < 0 || target >= currentItems.length) return
    var next = Model.normalizedItems(currentItems)
    var item = next.splice(index, 1)[0]
    next.splice(target, 0, item)
    replaceCurrentItems(next)
  }

  function launch(node) {
    var appLibrary = shell ? shell.appLibrary : null
    var desktopId = String(node.desktopId || "")
    if (!desktopId && node.cmd) {
      var first = Model.parseCommand(node.cmd)
      var entry = first.length > 0 ? DesktopEntries.heuristicLookup(first[0]) : null
      if (entry) desktopId = String(entry.id || "")
    }
    if (desktopId && appLibrary) {
      appLibrary.launch(desktopId, node.name)
      close()
      return
    }
    var args = Model.parseCommand(node.cmd)
    if (args.length === 0) {
      console.warn("Orbit: invalid or empty launch command for " + node.name)
      return
    }
    Util.execArgv(args)
    close()
  }

  function loadActivation(raw) {
    activationMods = ["SHIFT"]
    activationKey = "mouse:272"
    showNames = true
    animationPreset = "full"
    colorOverrides = {}
    try {
      var parsed = JSON.parse(String(raw || "{}")) || {}
      if (Array.isArray(parsed.mods) && typeof parsed.key === "string"
          && /^(mouse:\d+|[A-Z0-9_]{1,32})$/.test(parsed.key)) {
        activationMods = parsed.mods.filter(function(mod) {
          return ["SHIFT", "CTRL", "ALT", "SUPER"].indexOf(String(mod)) >= 0
        })
        activationKey = parsed.key
      }
      var settings = parsed.settings && typeof parsed.settings === "object" ? parsed.settings : {}
      if (typeof settings.showNames === "boolean") showNames = settings.showNames
      if (["full", "reduced", "off"].indexOf(settings.animation) >= 0)
        animationPreset = settings.animation
      var colors = settings.colors && typeof settings.colors === "object" && !Array.isArray(settings.colors)
        ? settings.colors : {}
      var loadedColors = {}
      var roles = ["background", "selectedBackground", "text", "accent", "border"]
      for (var i = 0; i < roles.length; i++) {
        var role = roles[i]
        if (validColor(colors[role])) loadedColors[role] = colors[role].toLowerCase()
      }
      colorOverrides = loadedColors
    } catch (e) {
      console.warn("Orbit: cannot parse " + activationPath + ": " + e)
    }
    ensureHyprlandIntegration()
  }

  function setActivation(mods, key) {
    if (!/^(mouse:\d+|[A-Z0-9_]{1,32})$/.test(String(key || ""))) return
    activationMods = mods.filter(function(mod) {
      return ["SHIFT", "CTRL", "ALT", "SUPER"].indexOf(String(mod)) >= 0
    })
    activationKey = String(key)
    saveSettings()
    ensureHyprlandIntegration()
  }

  function ensureHyprlandIntegration() {
    if (!bindingsReady) return
    var begin = "-- >>> orbit-menu (managed by the orbit settings, do not edit)"
    var end = "-- <<< orbit-menu"
    var start = bindingText.indexOf(begin)
    var finish = start < 0 ? -1 : bindingText.indexOf(end, start)
    var clean = start >= 0 && finish >= start
      ? bindingText.slice(0, start) + bindingText.slice(finish + end.length)
      : bindingText
    var combo = activationMods.concat([activationKey]).join(" + ")
    var mouse = activationKey.indexOf("mouse:") === 0
    var block = begin + "\no.bind(" + JSON.stringify(combo) +
      ", \"Orbit menu\", \"omarchy-shell shell toggle vyoltrava.orbit\", " +
      (mouse ? "{ mouse = true }" : "{ }") + ")\n" + end
    var updated = clean.replace(/\s+$/, "") + "\n\n" + block + "\n"
    if (updated === bindingText) return
    bindingText = updated
    bindingsFile.setText(updated)
    Quickshell.execDetached(["hyprctl", "reload"])
  }

  function loadBindings(raw) {
    bindingText = String(raw || "")
    if (!bindingsReady) bindingsReady = true
    ensureHyprlandIntegration()
  }

  function setCursorPosition(raw) {
    var match = /^(-?\d+)\s*,\s*(-?\d+)$/.exec(String(raw || "").trim())
    if (!match) return false
    cursorGlobalX = Number(match[1])
    cursorGlobalY = Number(match[2])
    return true
  }

  function setMonitorPosition(raw) {
    try {
      var monitors = JSON.parse(String(raw || "[]"))
      var selected = null
      for (var i = 0; i < monitors.length; i++) {
        var monitor = monitors[i]
        if (cursorGlobalX >= monitor.x && cursorGlobalX < monitor.x + monitor.width
            && cursorGlobalY >= monitor.y && cursorGlobalY < monitor.y + monitor.height) {
          selected = monitor
          break
        }
        if (monitor.focused) selected = monitor
      }
      if (selected) {
        monitorX = Number(selected.x) || 0
        monitorY = Number(selected.y) || 0
      }
      cursorPositionKnown = true
    } catch (e) {
      console.warn("Orbit: cannot determine the pointer monitor: " + e)
    }
  }

  function open(payloadJson) {
    if (opened && !closing) return
    closeAnimation.stop()
    foldAnimation.stop()
    closing = false
    ringContent.scale = 1
    ringContent.opacity = 1
    opened = true
    settingsOpen = false
    path = []
    selectedIndex = 0
    hoveredIndex = -1
    launchingIndex = -1
    openedAt = Date.now()
    menuFile.reload()
    activationFile.reload()
    bindingsFile.reload()
    refreshAppIcons()
    cursorPositionKnown = false
    monitorX = 0
    monitorY = 0
    cursorOutput.text = ""
    monitorsOutput.text = ""
    cursorProcess.running = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    if (!opened || closing) return
    closing = true
    settingsOpen = false
    hoveredIndex = -1
    pendingLaunchNode = null
    launchTimer.stop()
    closeAnimation.restart()
  }

  function finishClose() {
    opened = false
    settingsOpen = false
    closing = false
    launchingIndex = -1
    ringContent.scale = 1
    ringContent.opacity = 1
  }

  function foldAwayThen(callback) {
    pendingCall = callback
    foldAnimation.restart()
  }

  function goBack() {
    if (settingsOpen) {
      settingsOpen = false
    } else if (path.length > 0) {
      foldAwayThen(function() {
        path = path.slice(0, -1)
        selectedIndex = 0
      })
    } else {
      close()
    }
  }

  function moveSelection(delta) {
    if (settingsOpen || currentItems.length === 0) return
    selectedIndex = (selectedIndex + delta + currentItems.length) % currentItems.length
  }

  function activateIndex(index) {
    if (settingsOpen) return
    if (index < 0 || index >= currentItems.length) return
    var node = currentItems[index]
    if (node.type === "folder") {
      foldAwayThen(function() {
        path = path.concat([index])
        selectedIndex = 0
      })
      return
    }
    launchingIndex = index
    pendingLaunchNode = node
    launchTimer.restart()
  }

  function iconSource(icon) {
    return shell && shell.appLibrary
      ? shell.appLibrary.iconSource(icon)
      : Quickshell.iconPath(String(icon || "application-x-executable"), true)
  }

  FileView {
    id: menuFile
    path: root.menuPath
    watchChanges: true
    onLoaded: root.loadMenu(text())
    onFileChanged: reload()
    onLoadFailed: {
      root.loadMenu("")
      root.saveMenu()
    }
  }

  FileView {
    id: activationFile
    path: root.activationPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadActivation(text())
    onFileChanged: reload()
    onLoadFailed: root.loadActivation("")
  }

  FileView {
    id: bindingsFile
    path: root.bindingsPath
    watchChanges: true
    onLoaded: root.loadBindings(text())
    onFileChanged: reload()
    onLoadFailed: {
      console.warn("Orbit: cannot read " + root.bindingsPath + ", creating default bindings")
      root.bindingsReady = true
      root.ensureHyprlandIntegration()
    }
  }

  QtObject {
    id: cursorOutput
    property string text: ""
  }

  QtObject {
    id: monitorsOutput
    property string text: ""
  }

  Process {
    id: cursorProcess
    command: ["hyprctl", "cursorpos"]
    stdout: SplitParser {
      onRead: function(line) { cursorOutput.text = line }
    }
    onStarted: cursorOutput.text = ""
    onExited: if (root.setCursorPosition(cursorOutput.text)) monitorsProcess.running = true
  }

  Process {
    id: monitorsProcess
    command: ["hyprctl", "-j", "monitors"]
    stdout: SplitParser {
      onRead: function(line) { monitorsOutput.text += line + "\n" }
    }
    onStarted: monitorsOutput.text = ""
    onExited: root.setMonitorPosition(monitorsOutput.text)
  }

  OverlayWindow {
    id: overlay
    shown: root.opened
    WlrLayershell.namespace: "vyoltrava-orbit"

    MouseArea {
      anchors.fill: parent
      enabled: root.opened && !root.settingsOpen
      onClicked: function(mouse) {
        if (Date.now() - root.openedAt < 300) return
        var dx = mouse.x - root.centerX
        var dy = mouse.y - root.centerY
        if (Math.hypot(dx, dy) > root.orbitRadius + 70 * root.sizeScale) root.close()
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      enabled: root.opened && !root.settingsOpen
      onCloseRequested: root.goBack()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveSelection(dx)
        else root.moveSelection(dy)
      }
      onActivateRequested: root.activateIndex(root.selectedIndex)
    }

    ParallelAnimation {
      id: closeAnimation
      NumberAnimation {
        target: ringContent
        property: "scale"
        to: 0.6
        duration: root.motionDuration(140)
        easing.type: Easing.InQuad
      }
      NumberAnimation {
        target: ringContent
        property: "opacity"
        to: 0
        duration: root.motionDuration(140)
      }
      onFinished: root.finishClose()
    }

    SequentialAnimation {
      id: foldAnimation
      NumberAnimation {
        target: ringContent
        property: "scale"
        to: 0.6
        duration: root.motionDuration(130)
        easing.type: Easing.InQuad
      }
      NumberAnimation {
        target: ringContent
        property: "opacity"
        to: 0
        duration: root.motionDuration(90)
      }
      ScriptAction {
        script: {
          if (root.pendingCall) root.pendingCall()
          root.pendingCall = null
        }
      }
      onFinished: {
        ringContent.scale = 1
        ringContent.opacity = 1
      }
    }

    Timer {
      id: launchTimer
      interval: 120
      onTriggered: {
        var node = root.pendingLaunchNode
        if (node) root.launch(node)
      }
    }

    Item {
      id: ring
      visible: overlay.contentRevealed && root.opened && !root.settingsOpen
      anchors.fill: parent
      z: 1

      Item {
        id: ringContent
        x: root.centerX
        y: root.centerY
        width: 1
        height: 1

        Item {
          id: hoverLine
          visible: root.animationPreset !== "off" && root.hoveredIndex >= 0
          rotation: root.hoveredAngle * 180 / Math.PI

          Rectangle {
            x: root.centerSize / 2 + 2
            y: -1
            width: Math.max(0, root.orbitRadius - root.centerSize / 2 - 2)
            height: 2
            opacity: 0.55
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0; color: "transparent" }
              GradientStop { position: 0.35; color: root.menuAccentColor }
              GradientStop { position: 1; color: root.menuAccentColor }
            }
          }
          Rectangle {
            width: root.sparkSize
            height: root.sparkSize
            radius: root.sparkSize / 2
            y: -root.sparkSize / 2
            color: "#ffffff"
            visible: root.motionEnabled && root.animationPreset === "full"
            SequentialAnimation on x {
              running: root.motionEnabled && root.animationPreset === "full" && hoverLine.visible
              loops: Animation.Infinite
              NumberAnimation {
                from: root.centerSize / 2 + 2
                to: root.orbitRadius - 6
                duration: root.motionDuration(550)
                easing.type: Easing.InOutQuad
              }
              PauseAnimation { duration: root.motionDuration(120) }
            }
            SequentialAnimation on opacity {
              running: root.motionEnabled && root.animationPreset === "full" && hoverLine.visible
              loops: Animation.Infinite
              NumberAnimation { from: 0; to: 1; duration: root.motionDuration(275) }
              NumberAnimation { from: 1; to: 0.2; duration: root.motionDuration(275) }
              NumberAnimation { from: 0.2; to: 0; duration: root.motionDuration(120) }
              PauseAnimation { duration: root.motionDuration(120) }
            }
          }
        }

        Rectangle {
          id: centerButton
          x: -root.centerSize / 2
          y: -root.centerSize / 2
          width: root.centerSize
          height: root.centerSize
          radius: width / 2
          color: centerMouse.containsMouse ? root.selectedBackgroundColor : root.menuBackgroundColor
          border.width: 2 * root.sizeScale
          border.color: root.menuAccentColor
          Behavior on color { ColorAnimation { duration: root.motionDuration(120) } }

          Image {
            visible: root.path.length > 0 && root.showNames
            anchors.centerIn: parent
            source: Quickshell.iconPath("go-previous", true)
            sourceSize: Qt.size(root.centerIconSize, root.centerIconSize)
            width: root.centerIconSize
            height: root.centerIconSize
            fillMode: Image.PreserveAspectFit
          }
          Image {
            visible: root.path.length === 0
            anchors.centerIn: parent
            source: Qt.resolvedUrl("orbit.svg")
            sourceSize: Qt.size(root.centerIconSize, root.centerIconSize)
            width: root.centerIconSize
            height: root.centerIconSize
            fillMode: Image.PreserveAspectFit
          }
          MouseArea {
            id: centerMouse
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: if (containsMouse) root.hoveredIndex = -1
            onClicked: root.path.length > 0 ? root.goBack() : root.settingsOpen = true
          }
        }

        Text {
          visible: root.path.length > 0
          y: root.centerSize / 2 + 8
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.currentName
          color: root.menuTextColor
          font.pixelSize: 12
          font.bold: true
        }

        Repeater {
          model: root.currentItems

          delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property real angle: -Math.PI / 2 + index * 2 * Math.PI / Math.max(root.currentItems.length, 1)
            readonly property bool selected: root.selectedIndex === index
            property real pop: 0
            property bool hovered: false
            readonly property var folderItems: Array.isArray(modelData.children) ? modelData.children : []
            x: root.orbitRadius * Math.cos(angle) - width / 2
            y: root.orbitRadius * Math.sin(angle) - height / 2
            width: root.cellSize + 8
            height: root.cellSize + 8
            scale: root.motionEnabled ? pop : 1

            SequentialAnimation {
              running: ring.visible && !root.closing && root.motionEnabled
              PauseAnimation { duration: root.motionDuration(cell.index * 25) }
              NumberAnimation {
                target: cell
                property: "pop"
                from: 0
                to: 1
                duration: root.motionDuration(300)
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
              }
            }

            Rectangle {
              anchors.centerIn: parent
              width: root.cellSize
              height: root.cellSize
              radius: width / 2
              color: cell.hovered || cell.selected || root.launchingIndex === cell.index
                ? root.selectedBackgroundColor : root.menuBackgroundColor
              border.width: (cell.hovered || cell.selected || root.launchingIndex === cell.index ? 2 : 1) * root.sizeScale
              border.color: cell.hovered || cell.selected || root.launchingIndex === cell.index
                ? root.menuAccentColor : root.menuBorderColor
              Behavior on color { ColorAnimation { duration: root.motionDuration(120) } }
              Behavior on border.color { ColorAnimation { duration: root.motionDuration(120) } }

              Image {
                anchors.centerIn: parent
                width: root.cellIconSize
                height: root.cellIconSize
                sourceSize: Qt.size(width, height)
                source: root.iconSource(cell.modelData.icon)
                fillMode: Image.PreserveAspectFit
              }
            }

            Rectangle {
              visible: cell.modelData.type === "folder" && cell.folderItems.length > 0
              width: root.badgeSize
              height: root.badgeSize
              radius: root.badgeSize / 2
              x: root.cellSize - root.badgeSize * 0.9
              y: root.cellSize - root.badgeSize * 1.3
              color: root.menuAccentColor
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: cell.folderItems.length > 9 ? "9+" : String(cell.folderItems.length)
                color: root.menuBackgroundColor
                font.pixelSize: 10 * root.sizeScale
                font.bold: true
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              y: root.cellSize + 10
              width: root.cellSize + 24
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              textFormat: Text.PlainText
              visible: root.showNames
              text: cell.modelData.name
              color: root.menuTextColor
              font.pixelSize: 11
              style: Text.Outline
              styleColor: Qt.rgba(0, 0, 0, 0.55)
            }

            HoverHandler {
              cursorShape: Qt.PointingHandCursor
              onHoveredChanged: {
                cell.hovered = hovered
                if (hovered) {
                  root.selectedIndex = cell.index
                  root.hoveredIndex = cell.index
                } else if (root.hoveredIndex === cell.index) {
                  root.hoveredIndex = -1
                }
              }
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.activateIndex(cell.index)
            }

            Rectangle {
              visible: root.animationPreset === "full" && cell.hovered && cell.modelData.type !== "folder"
              anchors.centerIn: parent
              width: root.cellSize
              height: root.cellSize
              radius: width / 2
              color: "transparent"
              border.width: 2 * root.sizeScale
              border.color: root.menuAccentColor
              SequentialAnimation on scale {
                running: root.motionEnabled && root.animationPreset === "full" && cell.hovered
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 1.55; duration: root.motionDuration(900) }
                NumberAnimation { from: 1; to: 1; duration: 0 }
              }
              SequentialAnimation on opacity {
                running: root.motionEnabled && root.animationPreset === "full" && cell.hovered
                loops: Animation.Infinite
                NumberAnimation { from: 0.7; to: 0; duration: root.motionDuration(900) }
                NumberAnimation { from: 1; to: 1; duration: 0 }
              }
            }
          }
        }
      }
    }

    SettingsPage {
      anchors.fill: parent
      z: 2
      visible: overlay.contentRevealed && root.opened && (root.settingsOpen || opacity > 0)
      menuRoot: root
      opacity: root.settingsOpen ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: root.motionDuration(140) } }
    }
  }

  Component.onCompleted: {
    menuFile.reload()
    activationFile.reload()
    bindingsFile.reload()
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }
}
