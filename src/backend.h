// Backend — the orbit's state and work: the menu tree, installed apps,
// the activation hotkey, and placing the overlay window at the pointer.
#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QVariantList>

class QQuickWindow;

class Backend : public QObject {
    Q_OBJECT
    // Placement of the fullscreen transparent overlay, in logical pixels.
    Q_PROPERTY(int monitorWidth READ monitorWidth NOTIFY placementChanged)
    Q_PROPERTY(int monitorHeight READ monitorHeight NOTIFY placementChanged)
    Q_PROPERTY(qreal cursorX READ cursorX NOTIFY placementChanged) // menu center, window coords
    Q_PROPERTY(qreal cursorY READ cursorY NOTIFY placementChanged)
    Q_PROPERTY(bool placed READ placed NOTIFY placementChanged)

    // The children of the folder the orbit (and the editor) currently shows.
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    Q_PROPERTY(QString currentName READ currentName NOTIFY itemsChanged)
    Q_PROPERTY(QStringList breadcrumb READ breadcrumb NOTIFY itemsChanged)

    // Activation hotkey, e.g. "SHIFT + mouse:272".
    Q_PROPERTY(QString activationCombo READ activationCombo NOTIFY hotkeyChanged)

public:
    // Config/menu directory, Hyprland bindings file, hyprctl and the
    // .desktop search paths are injectable, so tests run off real user files.
    explicit Backend(const QString &configDirectory = {}, const QString &bindingsFile = {},
                     const QString &hyprctl = {}, const QStringList &desktopDirectories = {},
                     QObject *parent = nullptr);

    int monitorWidth() const { return m_monitorWidth; }
    int monitorHeight() const { return m_monitorHeight; }
    qreal cursorX() const { return m_cursorX; }
    qreal cursorY() const { return m_cursorY; }
    bool placed() const { return m_placed; }

    QVariantList items() const;
    QString currentName() const;
    QStringList breadcrumb() const;
    QString activationCombo() const;

    // Called by main.cpp once the window exists: sizes it to the monitor the
    // pointer is on, shows it, and moves it there through Hyprland (Wayland
    // apps cannot position themselves). Off Hyprland it just centers.
    void attachWindow(QQuickWindow *window, bool openSettings);

    Q_INVOKABLE void enter(int index);
    Q_INVOKABLE void goUp();
    Q_INVOKABLE void launch(int index);
    Q_INVOKABLE void quitApp();

    Q_INVOKABLE void addApplication(const QString &desktopId);
    Q_INVOKABLE void addFolder(const QString &name);
    Q_INVOKABLE void removeItem(int index);
    Q_INVOKABLE void renameItem(int index, const QString &name);
    Q_INVOKABLE void setCommand(int index, const QString &command);
    Q_INVOKABLE void setIcon(int index, const QString &icon);
    Q_INVOKABLE void moveItem(int index, int delta); // -1 left, +1 right
    Q_INVOKABLE void selectBreadcrumb(int level); // 0 = root

    // Installed .desktop applications, filtered by a substring of the name.
    Q_INVOKABLE QVariantList searchApplications(const QString &filter) const;

    // Applies a new activation hotkey: rewrites the managed block in the
    // Hyprland bindings file and reloads the compositor config.
    Q_INVOKABLE void setActivation(const QStringList &mods, const QString &key);

    // The managed Lua block, also exercised by tests.
    QString hyprlandBlock() const;

    // Parse one .desktop file into {id, name, icon, exec}; null if hidden.
    static QVariantMap parseDesktopFile(const QString &path);

signals:
    void placementChanged();
    void itemsChanged();
    void hotkeyChanged();

private:
    QJsonArray nodeArray(const QStringList &segments) const;
    void setNodeArray(const QStringList &segments, const QJsonArray &value);
    static QJsonArray arrayAt(const QJsonArray &root, const QStringList &segments);
    static QJsonArray replaceArrayAt(const QJsonArray &root, const QStringList &segments,
                                     const QJsonArray &value);
    void save();
    void load();
    void ensureDefaultMenu();
    void scanApplications();
    void loadHotkey();
    void ensureHyprlandIntegration();
    void reloadHyprland();

    QString m_configDirectory;
    QString m_bindingsFile;
    QString m_hyprctl;
    QStringList m_desktopDirectories;
    QJsonObject m_menu;      // {"items": [...]}
    QVariantList m_apps;     // installed applications
    QStringList m_mods;      // hotkey modifiers, e.g. ["SHIFT"]
    QString m_key;           // hotkey key, e.g. "mouse:272"
    QString m_currentPath;   // "" = root, "2.0" = third item's first child

    int m_monitorWidth = 1280;
    int m_monitorHeight = 800;
    qreal m_cursorX = 640;
    qreal m_cursorY = 400;
    bool m_placed = false;
};
