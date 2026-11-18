// orbit — a radial launcher: one ring of cells around the pointer, folders
// open the next ring, the center opens settings.
#include <QFile>
#include <QGuiApplication>
#include <QIcon>
#include <QLockFile>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QUrl>

#include <cerrno>
#include <csignal>
#include <unistd.h>

#include "backend.h"
#include "iconprovider.h"
#include "theme.h"
#include "translator.h"

// `orbit toggle` is what the Hyprland bind runs: close the open overlay, or
// spawn a fresh one. Everything else (no argument, `settings`) opens it.
static int toggle()
{
    const QString lockPath = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/orbit.lock";
    QLockFile lock(lockPath);
    qint64 pid = 0;
    QString host, user;
    if (lock.getLockInfo(&pid, &host, &user) && pid > 0) {
        // A crashed or killed run leaves its lock behind; only a live pid
        // means the overlay is really open.
        if (::kill(static_cast<pid_t>(pid), 0) == 0 || errno == EPERM) {
            ::kill(static_cast<pid_t>(pid), SIGTERM);
            return 0;
        }
        QFile::remove(lockPath); // stale lock from a dead run
    }
    QProcess::startDetached(QCoreApplication::applicationFilePath(), {"open"});
    return 0;
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("orbit");
    app.setApplicationVersion("0.1.0");
    app.setDesktopFileName("orbit");
    app.setWindowIcon(QIcon::fromTheme("orbit"));

    // `orbit toggle` is what the Hyprland bind runs: close the open overlay,
    // or spawn a fresh one. Everything else opens the overlay.
    const QStringList arguments = app.arguments();
    if (arguments.contains("toggle"))
        return toggle();

    QQuickStyle::setStyle("Material");

    Translator translator;
    app.installTranslator(&translator);

    Theme theme;
    Backend backend;
    IconProvider icons;

    // One overlay at a time; a second launch is a no-op.
    QLockFile lock(QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/orbit.lock");
    if (!lock.tryLock(0))
        return 0;

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    // The engine takes ownership of the provider and deletes it itself.
    engine.addImageProvider("icons", new IconProvider);
    engine.load(QUrl("qrc:/Main.qml"));
    qWarning() << "DEBUG rootObjects:" << engine.rootObjects().size();
    if (engine.rootObjects().isEmpty())
        return 1;

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    backend.attachWindow(window, arguments.contains("settings"));

    return app.exec();
}
