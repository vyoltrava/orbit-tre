.pragma library

var maxItems = 12
var maxNameLength = 100
var maxIconLength = 256
var maxCommandLength = 2048

function normalizedItems(value) {
  if (!Array.isArray(value)) return []

  var result = []
  for (var i = 0; i < value.length && result.length < maxItems; i++) {
    var item = value[i]
    if (!item || typeof item !== "object" || Array.isArray(item)) continue

    var name = typeof item.name === "string" ? item.name.slice(0, maxNameLength) : ""
    if (!name) continue

    if (item.type === "folder" || Array.isArray(item.children)) {
      result.push({
        type: "folder",
        name: name,
        icon: typeof item.icon === "string" ? item.icon.slice(0, maxIconLength) : "folder",
        children: normalizedItems(item.children)
      })
      continue
    }

    var cmd = typeof item.cmd === "string" ? item.cmd.slice(0, maxCommandLength).trim() : ""
    var desktopId = typeof item.desktopId === "string" ? item.desktopId.slice(0, 256) : ""
    if (!cmd && !desktopId) continue
    result.push({
      type: "app",
      name: name,
      icon: typeof item.icon === "string" ? item.icon.slice(0, maxIconLength) : "application-x-executable",
      cmd: cmd,
      desktopId: desktopId
    })
  }
  return result
}

function itemsAt(tree, path) {
  var items = Array.isArray(tree) ? tree : []
  for (var i = 0; i < path.length; i++) {
    var index = Number(path[i])
    if (!isFinite(index) || Math.floor(index) !== index || index < 0 || index >= items.length) return []
    var node = items[index]
    if (!node || node.type !== "folder" || !Array.isArray(node.children)) return []
    items = node.children
  }
  return items
}

function entriesFromSearchResults(results) {
  if (!Array.isArray(results)) return []
  var entries = []
  for (var i = 0; i < results.length; i++) {
    var entry = results[i] && results[i].entry
    if (entry && typeof entry === "object" && !Array.isArray(entry)) entries.push(entry)
  }
  return entries
}

function replaceArrayAt(tree, path, replacement) {
  if (!Array.isArray(tree) || !Array.isArray(path) || !Array.isArray(replacement)) return tree
  if (path.length === 0) return replacement

  var index = Number(path[0])
  if (!isFinite(index) || Math.floor(index) !== index || index < 0 || index >= tree.length) return tree
  var result = tree.slice()
  var node = result[index]
  if (!node || node.type !== "folder" || !Array.isArray(node.children)) return tree
  var nextNode = Object.assign({}, node)
  nextNode.children = replaceArrayAt(node.children, path.slice(1), replacement)
  result[index] = nextNode
  return result
}

function parseCommand(value) {
  var command = String(value || "").replace(/%[a-zA-Z]/g, "").trim()
  if (!command || command.length > maxCommandLength) return []

  var args = []
  var token = ""
  var quote = ""
  var escaped = false
  var started = false

  for (var i = 0; i < command.length; i++) {
    var ch = command.charAt(i)
    if (escaped) {
      token += ch
      escaped = false
      started = true
    } else if (ch === "\\" && quote !== "'") {
      escaped = true
      started = true
    } else if (quote) {
      if (ch === quote) quote = ""
      else token += ch
    } else if (ch === "'" || ch === '"') {
      quote = ch
      started = true
    } else if (/\s/.test(ch)) {
      if (started) {
        args.push(token)
        token = ""
        started = false
      }
    } else if (/[;&|<>`$]/.test(ch)) {
      return []
    } else {
      token += ch
      started = true
    }
  }

  if (escaped || quote) return []
  if (started) args.push(token)
  return args
}

function defaultItems(entries, appLibrary) {
  var candidates = [
    "firefox", "chromium", "org.chromium.Chromium", "brave-browser",
    "org.gnome.Nautilus", "org.kde.dolphin", "nautilus", "thunar",
    "Alacritty", "alacritty", "foot", "kitty", "org.wezfurlong.wezterm",
    "code", "code-oss", "com.visualstudio.code", "org.telegram.desktop"
  ]
  var byId = Object.create(null)
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i]
    if (entry && entry.id) byId[String(entry.id).replace(/\.desktop$/, "")] = entry
  }

  var items = []
  for (var c = 0; c < candidates.length && items.length < 6; c++) {
    var app = byId[candidates[c]]
    if (!app) continue
    items.push({
      type: "app",
      name: appLibrary ? (appLibrary.entryName(app) || app.name || candidates[c]) : (app.name || candidates[c]),
      icon: app.icon || "application-x-executable",
      desktopId: app.id
    })
  }
  items.push({ type: "folder", name: "Tools", icon: "folder", children: [] })
  return items
}
