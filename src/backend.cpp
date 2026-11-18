// Backend — the orbit's state and work. The menu is one JSON tree at
// ~/.config/orbit/menu.json; every cell is an app launcher or a folder whose
// children become the next ring out.
#include "backend.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QScreen>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTimer>

#include <QQuickWindow>

#include <algorithm>
#include <cstdio>

static const char *kManagedBegin = "-- >>> orbit-menu (managed by the orbit settings, do not edit)";
static const char *kManagedEnd = "-- <<< orbit-menu";

Backend::Backend(const QString &configDirectory, const QString &bindingsFile, const QString &hyprctl,
                 const QStringList &desktopDirectories, QObject *parent)
    : QObject(parent) {
    m_configDirectory = !configDirectory.isEmpty() ? configDirectory
                      : QDir::homePath() + "/.config/orbit";
    m_bindingsFile = !bindingsFile.isEmpty() ? bindingsFile
                   : QDir::homePath() + "/.config/hypr/bindings.lua";
    m_hyprctl = !hyprctl.isEmpty() ? hyprctl
              : !qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE")
                  ? QStandardPaths::findExecutable("hyprctl") : QString();

    m_desktopDirectories = desktopDirectories;
    if (m_desktopDirectories.isEmpty()) {
        m_desktopDirectories << QDir::homePath() + "/.local/share/applications";
        const QString dataHome = qEnvironmentVariable("XDG_DATA_HOME");
        if (!dataHome.isEmpty())
            m_desktopDirectories << dataHome + "/applications";
        const QString dataDirs = qEnvironmentVariable("XDG_DATA_DIRS");
        for (const QString &dir : (dataDirs.isEmpty() ? QStringLiteral("/usr/local/share:/usr/share")
                                                      : dataDirs).split(':', Qt::SkipEmptyParts))
            m_desktopDirectories << dir + "/applications";
    }

    QDir().mkpath(m_configDirectory);
    load();
    scanApplications();
    if (m_menu.value("items").toArray().isEmpty()) {
        ensureDefaultMenu();
        save();
    }
    loadHotkey();
    // Write the default Shift+LMB bind and the window rules on first run.
    ensureHyprlandIntegration();
}

// ---------------------------------------------------------------- menu tree

static QStringList pathSegments(const QString &path)
{
    return path.isEmpty() ? QStringList{} : path.split('.', Qt::SkipEmptyParts);
}

QJsonArray Backend::arrayAt(const QJsonArray &root, const QStringList &segments) {
    QJsonArray current = root;
    for (const QString &segment : segments) {
        const int index = segment.toInt();
        if (index < 0 || index >= current.size())
            return {};
        const QJsonValue value = current.at(index);
        if (value.toObject().value("type").toString() != "folder")
            return {};
        current = value.toObject().value("children").toArray();
    }
    return current;
}

QJsonArray Backend::replaceArrayAt(const QJsonArray &root, const QStringList &segments,
                                   const QJsonArray &value) {
    if (segments.isEmpty())
        return value;
    QJsonArray result = root;
    const int index = segments.first().toInt();
    if (index < 0 || index >= result.size())
        return root;
    QJsonObject node = result.at(index).toObject();
    if (node.value("type").toString() != "folder")
        return root;
    node.insert("children", replaceArrayAt(node.value("children").toArray(),
                                           segments.mid(1), value));
    result.replace(index, node);
    return result;
}

QJsonArray Backend::nodeArray(const QStringList &segments) const {
    return arrayAt(m_menu.value("items").toArray(), segments);
}

void Backend::setNodeArray(const QStringList &segments, const QJsonArray &value) {
    m_menu.insert("items", replaceArrayAt(m_menu.value("items").toArray(), segments, value));
}

void Backend::load() {
    QFile file(m_configDirectory + "/menu.json");
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    if (document.isObject())
        m_menu = document.object();
}

void Backend::save() {
    const QString path = m_configDirectory + "/menu.json";
    // Atomic: write beside the target, then rename, so a crash mid-write
    // never loses the menu.
    QTemporaryDir stash(m_configDirectory + "/.orbit-XXXXXX");
    const QString temporary = stash.isValid() ? stash.filePath("menu.json") : path + ".tmp";
    QFile file(temporary);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(m_menu).toJson());
    file.close();
    QFile::remove(path);
    QFile::rename(temporary, path);
}

// The first run menu: whatever of the usual suspects is actually installed,
// plus one empty folder so the nesting is discoverable.
void Backend::ensureDefaultMenu() {
    QJsonArray items;
    const QStringList candidates{
        "firefox", "chromium", "org.chromium.Chromium", "brave-browser",
        "org.gnome.Nautilus", "org.kde.dolphin", "nautilus", "thunar", "pcmanfm",
        "Alacritty", "alacritty", "foot", "footclient", "kitty", "org.wezfurlong.wezterm",
        "code", "code-oss", "com.visualstudio.code", "jetbrains-idea",
        "org.telegram.desktop", "discord", "thunderbird",
        "org.gnome.Settings", "org.kde.systemsettings", "gnome-control-center",
    };
    for (const QString &id : candidates) {
        for (const QVariant &app : std::as_const(m_apps)) {
            if (app.toMap().value("id").toString() == id) {
                const QVariantMap map = app.toMap();
                QJsonObject node;
                node.insert("type", "app");
                node.insert("name", map.value("name").toString());
                node.insert("icon", map.value("icon").toString());
                node.insert("cmd", map.value("exec").toString());
                items.append(node);
                break;
            }
        }
        if (items.size() >= 6)
            break;
    }
    QJsonObject tools;
    tools.insert("type", "folder");
    tools.insert("name", QObject::tr("Tools"));
    tools.insert("icon", "folder");
    tools.insert("children", QJsonArray{});
    items.append(tools);
    m_menu.insert("items", items);
}

void Backend::scanApplications() {
    m_apps.clear();
    for (const QString &directory : std::as_const(m_desktopDirectories)) {
        const QDir dir(directory);
        if (!dir.exists())
            continue;
        for (const QFileInfo &entry : dir.entryInfoList({"*.desktop"}, QDir::Files)) {
            const QVariantMap app = parseDesktopFile(entry.absoluteFilePath());
            if (app.isEmpty())
                continue;
            // Local overrides shadow system entries with the same id.
            for (int i = 0; i < m_apps.size(); ++i)
                if (m_apps.at(i).toMap().value("id").toString() == app.value("id").toString())
                    m_apps.removeAt(i--);
            m_apps.append(app);
        }
    }
    std::sort(m_apps.begin(), m_apps.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("name").toString().compare(
                   b.toMap().value("name").toString(), Qt::CaseInsensitive) < 0;
    });
}

QVariantMap Backend::parseDesktopFile(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QString name, genericName, icon, exec;
    bool inMain = false, hidden = false;
    const QString localeName = QLocale().name(); // e.g. "ru_RU"
    const QString localeBase = localeName.section('_', 0, 0);
    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line == "[Desktop Entry]") { inMain = true; continue; }
        if (line.startsWith('[')) { inMain = false; continue; }
        if (!inMain) continue;
        const int equals = line.indexOf('=');
        if (equals < 0) continue;
        const QString key = line.left(equals).trimmed();
        const QString value = line.mid(equals + 1).trimmed();
        if (key == "Name")
            genericName = value;
        else if (key == "Name[" + localeName + "]" || key == "Name[" + localeBase + "]")
            name = value;
        else if (key == "Icon") icon = value;
        else if (key == "Exec") exec = value;
        else if (key == "NoDisplay" || key == "Hidden") hidden = hidden || value.compare("true", Qt::CaseInsensitive) == 0;
    }
    if (hidden || exec.isEmpty())
        return {};
    if (name.isEmpty())
        name = genericName;
    return {{"id", QFileInfo(path).completeBaseName()}, {"name", name.isEmpty() ? QFileInfo(path).completeBaseName() : name},
            {"icon", icon}, {"exec", exec}};
}

QVariantList Backend::searchApplications(const QString &filter) const {
    QVariantList result;
    for (const QVariant &app : m_apps) {
        if (!filter.isEmpty() && !app.toMap().value("name").toString()
                                     .contains(filter, Qt::CaseInsensitive))
            continue;
        result.append(app);
    }
    return result;
}

// ------------------------------------------------------------- current path

QVariantList Backend::items() const {
    QVariantList result;
    const QJsonArray array = nodeArray(pathSegments(m_currentPath));
    for (int i = 0; i < array.size(); ++i) {
        const QJsonObject node = array.at(i).toObject();
        const bool folder = node.value("type").toString() == "folder";
        result.append(QJsonObject{
            {"index", i},
            {"type", node.value("type").toString()},
            {"name", node.value("name").toString()},
            {"icon", node.value("icon").toString()},
            {"cmd", node.value("cmd").toString()},
            {"folder", folder},
            {"count", folder ? node.value("children").toArray().size() : 0},
        });
    }
    return result;
}

QString Backend::currentName() const {
    const QStringList segments = pathSegments(m_currentPath);
    if (segments.isEmpty())
        return {};
    const QJsonArray parent = arrayAt(m_menu.value("items").toArray(), segments.mid(0, segments.size() - 1));
    const int last = segments.last().toInt();
    if (last < 0 || last >= parent.size())
        return {};
    return parent.at(last).toObject().value("name").toString();
}

QStringList Backend::breadcrumb() const {
    QStringList names;
    const QStringList segments = pathSegments(m_currentPath);
    QJsonArray level = m_menu.value("items").toArray();
    names.append(tr("Root"));
    for (const QString &segment : segments) {
        const int index = segment.toInt();
        if (index < 0 || index >= level.size())
            break;
        names.append(level.at(index).toObject().value("name").toString());
        level = level.at(index).toObject().value("children").toArray();
    }
    return names;
}

void Backend::enter(int index) {
    m_currentPath = m_currentPath.isEmpty() ? QString::number(index)
                  : m_currentPath + '.' + QString::number(index);
    emit itemsChanged();
}

void Backend::goUp() {
    QStringList segments = pathSegments(m_currentPath);
    if (segments.isEmpty())
        return;
    segments.removeLast();
    m_currentPath = segments.join('.');
    emit itemsChanged();
}

void Backend::selectBreadcrumb(int level) {
    const QStringList segments = pathSegments(m_currentPath);
    if (level < 0 || level > segments.size())
        return;
    m_currentPath = segments.mid(0, level).join('.');
    emit itemsChanged();
}

void Backend::launch(int index) {
    const QJsonArray array = nodeArray(pathSegments(m_currentPath));
    if (index < 0 || index >= array.size())
        return;
    const QJsonObject node = array.at(index).toObject();
    QString command = node.value("cmd").toString();
    // Desktop entry field codes (%f, %u, ...) have no file to stand for here.
    static const QRegularExpression fieldCodes("%[a-zA-Z%]");
    command = command.replace(fieldCodes, "").trimmed();
    if (command.isEmpty())
        return;
    QProcess::startDetached("/bin/sh", {"-c", command});
}

// ----------------------------------------------------------------- editing

void Backend::addApplication(const QString &desktopId) {
    for (const QVariant &app : std::as_const(m_apps)) {
        if (app.toMap().value("id").toString() != desktopId)
            continue;
        const QVariantMap map = app.toMap();
        QJsonObject node;
        node.insert("type", "app");
        node.insert("name", map.value("name").toString());
        node.insert("icon", map.value("icon").toString());
        node.insert("cmd", map.value("exec").toString());
        QJsonArray array = nodeArray(pathSegments(m_currentPath));
        if (array.size() >= 12)
            return; // the ring gets too tight beyond twelve cells
        array.append(node);
        setNodeArray(pathSegments(m_currentPath), array);
        save();
        emit itemsChanged();
        return;
    }
}

void Backend::addFolder(const QString &name) {
    QJsonArray array = nodeArray(pathSegments(m_currentPath));
    if (array.size() >= 12)
        return;
    QJsonObject node;
    node.insert("type", "folder");
    node.insert("name", name.isEmpty() ? tr("Folder") : name);
    node.insert("icon", "folder");
    node.insert("children", QJsonArray{});
    array.append(node);
    setNodeArray(pathSegments(m_currentPath), array);
    save();
    emit itemsChanged();
}

void Backend::removeItem(int index) {
    QJsonArray array = nodeArray(pathSegments(m_currentPath));
    if (index < 0 || index >= array.size())
        return;
    array.removeAt(index);
    setNodeArray(pathSegments(m_currentPath), array);
    save();
    emit itemsChanged();
}

void Backend::renameItem(int index, const QString &name) {
    QJsonArray array = nodeArray(pathSegments(m_currentPath));
    if (index < 0 || index >= array.size())
        return;
    QJsonObject node = array.at(index).toObject();
    node.insert("name", name);
    array.replace(index, node);
    setNodeArray(pathSegments(m_currentPath), array);
    save();
    emit itemsChanged();
}

void Backend::setCommand(int index, const QString &command) {
    QJsonArray array = nodeArray(pathSegments(m_currentPath));
    if (index < 0 || index >= array.size())
        return;
    QJsonObject node = array.at(index).toObject();
    node.insert("cmd", command);
    array.replace(index, node);
    setNodeArray(pathSegments(m_currentPath), array);
    save();
    emit itemsChanged();
}

void Backend::setIcon(int index, const QString &icon) {
    QJsonArray array = nodeArray(pathSegments(m_currentPath));
    if (index < 0 || index >= array.size())
        return;
    QJsonObject node = array.at(index).toObject();
    node.insert("icon", icon);
    array.replace(index, node);
    setNodeArray(pathSegments(m_currentPath), array);
    save();
    emit itemsChanged();
}

void Backend::moveItem(int index, int delta) {
    QJsonArray array = nodeArray(pathSegments(m_currentPath));
    const int target = index + delta;
    if (index < 0 || index >= array.size() || target < 0 || target >= array.size())
        return;
    const QJsonValue moving = array.at(index);
    array.replace(index, array.at(target));
    array.replace(target, moving);
    setNodeArray(pathSegments(m_currentPath), array);
    save();
    emit itemsChanged();
}

// ------------------------------------------------------------------ hotkey

void Backend::loadHotkey() {
    QFile file(m_configDirectory + "/config.json");
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonObject object = QJsonDocument::fromJson(file.readAll()).object();
        m_mods.clear();
        for (const QJsonValue &value : object.value("mods").toArray())
            m_mods.append(value.toString());
        m_key = object.value("key").toString();
    }
    if (m_mods.isEmpty() && m_key.isEmpty()) {
        m_mods = {"SHIFT"};
        m_key = "mouse:272";
    }
}

QString Backend::activationCombo() const {
    QStringList parts = m_mods;
    if (!m_key.isEmpty())
        parts.append(m_key);
    return parts.join(" + ");
}

QString Backend::hyprlandBlock() const {
    QString block = QString("%1\n").arg(kManagedBegin);
    const bool mouse = m_key.startsWith("mouse:");
    block += QString("o.bind(\"%1\", \"Orbit menu\", \"orbit toggle\", %2)\n")
                 .arg(activationCombo(), mouse ? "{ mouse = true }" : "{ }");
    block += "o.window(\"orbit\", { float = true, border_size = 0, size = \"100% 100%\" })\n";
    block += kManagedEnd;
    return block;
}

void Backend::ensureHyprlandIntegration() {
    if (m_hyprctl.isEmpty() || m_bindingsFile.isEmpty())
        return;
    QFile file(m_bindingsFile);
    QString contents;
    if (file.open(QIODevice::ReadOnly)) {
        contents = QString::fromUtf8(file.readAll());
        file.close();
    }
    static const QRegularExpression blockRemoval(
        QRegularExpression::escape(kManagedBegin) + ".*" + QRegularExpression::escape(kManagedEnd) + "\\n?",
        QRegularExpression::DotMatchesEverythingOption);
    const QString cleaned = contents.replace(blockRemoval, "");
    const QString updated = cleaned.trimmed() + "\n\n" + hyprlandBlock() + "\n";
    if (updated == contents)
        return;
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.write(updated.toUtf8());
        reloadHyprland();
    }
}

void Backend::setActivation(const QStringList &mods, const QString &key) {
    if (key.isEmpty())
        return;
    m_mods = mods;
    m_key = key;
    QFile file(m_configDirectory + "/config.json");
    if (file.open(QIODevice::WriteOnly)) {
        QJsonArray modsArray;
        for (const QString &mod : mods)
            modsArray.append(mod);
        file.write(QJsonDocument(QJsonObject{{"mods", modsArray}, {"key", key}}).toJson());
    }
    emit hotkeyChanged();
    ensureHyprlandIntegration();
}

void Backend::reloadHyprland() {
    if (m_hyprctl.isEmpty())
        return;
    QProcess::startDetached(m_hyprctl, {"reload"});
}

// --------------------------------------------------------------- placement

void Backend::attachWindow(QQuickWindow *window, bool openSettings) {
    if (!window)
        return;
    window->setFlags(window->flags() | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);

    qreal globalX = 0, globalY = 0;
    bool havePointer = false;
    if (!m_hyprctl.isEmpty()) {
        // Where the bind caught the pointer, and which monitor holds it.
        QProcess cursor;
        cursor.start(m_hyprctl, {"cursorpos"});
        if (cursor.waitForFinished(500)) {
            const QString output = QString::fromUtf8(cursor.readAllStandardOutput()).trimmed();
            const QRegularExpression match("^(\\d+)\\s*,\\s*(\\d+)$");
            const auto m = match.match(output);
            if (m.hasMatch()) {
                globalX = m.captured(1).toDouble();
                globalY = m.captured(2).toDouble();
                havePointer = true;
            }
        }
    }

    QScreen *screen = nullptr;
    if (havePointer)
        screen = QGuiApplication::screenAt(QPoint(int(globalX), int(globalY)));
    if (!screen)
        screen = QGuiApplication::primaryScreen();
    const QRect geometry = screen->geometry(); // global coordinates

    if (havePointer) {
        m_monitorWidth = geometry.width();
        m_monitorHeight = geometry.height();
        m_cursorX = globalX - geometry.x();
        m_cursorY = globalY - geometry.y();
    } else {
        m_monitorWidth = geometry.width();
        m_monitorHeight = geometry.height();
        m_cursorX = geometry.width() / 2.0;
        m_cursorY = geometry.height() / 2.0;
    }
    emit placementChanged();

    window->setWidth(m_monitorWidth);
    window->setHeight(m_monitorHeight);
    window->setScreen(screen);
    window->show();

    if (!havePointer || m_hyprctl.isEmpty()) {
        m_placed = true;
        emit placementChanged();
        if (openSettings)
            QMetaObject::invokeMethod(window, "openSettingsPage");
        return;
    }

    // Wayland apps cannot place themselves, and Hyprland opens the overlay
    // wherever it likes. So once the window is mapped, read its real global
    // position from hyprctl and put the ring at the pointer relative to it —
    // wherever the compositor dropped the window, the ring lands on the cursor.
    auto *timer = new QTimer(window);
    int attempts = 0;
    timer->setInterval(40);
    QObject::connect(timer, &QTimer::timeout, window,
                     [this, window, timer, globalX, globalY, openSettings, &attempts]() mutable {
        QProcess clients;
        clients.start(m_hyprctl, {"-j", "clients"});
        if (clients.waitForFinished(300)) {
            const QJsonDocument document = QJsonDocument::fromJson(clients.readAllStandardOutput());
            for (const QJsonValue &value : document.array()) {
                const QJsonObject client = value.toObject();
                if (client.value("class").toString() != "orbit")
                    continue;
                const QJsonArray at = client.value("at").toArray();
                if (at.size() < 2)
                    break;
                m_cursorX = globalX - at.at(0).toDouble();
                m_cursorY = globalY - at.at(1).toDouble();
                timer->stop();
                timer->deleteLater();
                m_placed = true;
                emit placementChanged();
                if (openSettings)
                    QMetaObject::invokeMethod(window, "openSettingsPage");
                return;
            }
        }
        if (++attempts > 40) {
            // Give up on the exact spot; the monitor-relative fallback stands.
            timer->stop();
            timer->deleteLater();
            m_placed = true;
            emit placementChanged();
            if (openSettings)
                QMetaObject::invokeMethod(window, "openSettingsPage");
        }
    });
    timer->start();
}

void Backend::quitApp() {
    QCoreApplication::quit();
}
