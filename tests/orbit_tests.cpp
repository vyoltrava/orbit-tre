#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"

class OrbitTests : public QObject {
    Q_OBJECT

    // A Backend against a temp config directory, plus the menu.json it wrote.
    static Backend makeBackend(const QTemporaryDir &dir, const QString &bindings = {})
    {
        return Backend(dir.path(), bindings, {}, {});
    }

    static QJsonObject readMenu(const QTemporaryDir &dir)
    {
        QFile file(dir.path() + "/menu.json");
        if (!file.open(QIODevice::ReadOnly))
            return {};
        return QJsonDocument::fromJson(file.readAll()).object();
    }

    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }

private slots:
    void createsADefaultMenu()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path() + "/bindings.lua", {}, {});
        QVERIFY(backend.items().size() > 0);
        QVERIFY(!readMenu(dir).value("items").toArray().isEmpty());
    }

    void nestsFolders()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path() + "/bindings.lua", {}, {});

        backend.addFolder("Dev");
        QCOMPARE(backend.items().constLast().toMap().value("type").toString(), "folder");

        const int index = backend.items().size() - 1;
        backend.enter(index);
        QCOMPARE(backend.currentName(), QString("Dev"));
        backend.addFolder("Projects");
        QCOMPARE(backend.items().size(), 1);

        backend.goUp();
        QCOMPARE(backend.items().size(), index + 1);
        QCOMPARE(readMenu(dir).value("items").toArray().at(index).toObject()
                     .value("children").toArray().size(), 1);
    }

    void editsCells()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path() + "/bindings.lua", {}, {});
        const int count = backend.items().size();

        backend.addFolder("Test");
        const int index = backend.items().size() - 1;
        backend.renameItem(index, "Renamed");
        QCOMPARE(backend.items().at(index).toMap().value("name").toString(), "Renamed");

        backend.moveItem(index, -1);
        QCOMPARE(backend.items().at(index - 1).toMap().value("name").toString(), "Renamed");

        backend.removeItem(index - 1);
        QCOMPARE(backend.items().size(), count);
    }

    void keepsSelectionAcrossEdits()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path() + "/bindings.lua", {}, {});
        backend.addFolder("One");
        backend.addFolder("Two");
        backend.addFolder("Three");
        backend.removeItem(2);
        // No crash, and the tree survives on disk.
        QCOMPARE(readMenu(dir).value("items").toArray().size(), backend.items().size());
    }

    void findsDesktopApplications()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("applications");
        write(dir.path() + "/applications/foo.desktop",
              "[Desktop Entry]\nName=Foo App\nExec=foo %U\nIcon=foo-icon\nType=Application\n");
        write(dir.path() + "/applications/hidden.desktop",
              "[Desktop Entry]\nName=Hidden\nExec=hidden\nNoDisplay=true\n");

        Backend backend(dir.path(), dir.path() + "/bindings.lua", {}, {dir.path() + "/applications"});
        const QVariantList apps = backend.searchApplications("");
        QCOMPARE(apps.size(), 1);
        QCOMPARE(apps.constFirst().toMap().value("name").toString(), "Foo App");
        QCOMPARE(apps.constFirst().toMap().value("exec").toString(), "foo %U");
        QVERIFY(!backend.searchApplications("zzz").size());
        QVERIFY(backend.searchApplications("foo").size() == 1);
    }

    void keepsShowNamesSetting()
    {
        QTemporaryDir dir;
        Backend backend(dir.path(), dir.path() + "/bindings.lua", {}, {});
        QVERIFY(backend.showNames()); // default is on

        backend.setShowNames(false);
        QCOMPARE(backend.showNames(), false);

        // The hotkey survives the names toggle, and both load back together.
        backend.setActivation({"SUPER"}, "O");
        Backend reloaded(dir.path(), dir.path() + "/bindings.lua", {}, {});
        QCOMPARE(reloaded.showNames(), false);
        QCOMPARE(reloaded.activationCombo(), QString("SUPER + O"));
    }

    void readsLegacyShowNames()
    {
        QTemporaryDir dir;
        write(dir.path() + "/config.json",
              R"({"settings": {"showNames": false}, "key": "F9", "mods": []})");
        Backend backend(dir.path(), dir.path() + "/bindings.lua", {}, {});
        QCOMPARE(backend.showNames(), false);
        QCOMPARE(backend.activationCombo(), QString("F9"));
    }

    void writesTheHotkeyBlock()
    {
        QTemporaryDir dir;
        const QString bindings = dir.path() + "/bindings.lua";
        write(bindings, "-- my own binds\no.bind(\"SUPER + Q\", \"Quit\", \"quit\")\n");

        Backend backend(dir.path(), bindings, {}, {});
        backend.setActivation({"SHIFT"}, "mouse:272");

        auto read = [&bindings]() -> QString {
            QFile file(bindings);
            const bool ok = file.open(QIODevice::ReadOnly);
            if (!ok)
                return {};
            return QString::fromUtf8(file.readAll());
        };
        const QString contents = read();
        QVERIFY(!contents.isEmpty());
        QVERIFY(contents.contains("SHIFT + mouse:272"));
        QVERIFY(contents.contains("orbit toggle"));
        QVERIFY(contents.contains("o.window(\"orbit\""));
        QVERIFY(contents.contains("-- my own binds")); // user content untouched
        QVERIFY(contents.count(">>> orbit-menu") == 1);

        // Setting another combo rewrites the block, never duplicates it.
        backend.setActivation({"SUPER"}, "O");
        const QString updated = read();
        QVERIFY(updated.contains("SUPER + O"));
        QVERIFY(!updated.contains("mouse:272"));
        QVERIFY(updated.count(">>> orbit-menu") == 1);
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        QFile colors(dir.path() + "/theme/colors.toml");
        QVERIFY(colors.open(QIODevice::WriteOnly));
        colors.write("accent = \"#112233\"\n");
        colors.close();

        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }

    void themeFollowsHyprlandRounding()
    {
        QTemporaryDir dir;
        const QString response = dir.filePath("response.json"), command = dir.filePath("hyprctl");
        auto write = [](const QString &path, const QByteArray &data) {
            QFile file(path);
            return file.open(QIODevice::WriteOnly) && file.write(data) == data.size();
        };
        QVERIFY(write(command, "#!/bin/sh\ncat '" + response.toUtf8() + "'\n"));
        QVERIFY(QFile::setPermissions(command, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        QVERIFY(write(response, "{\"int\":0}"));

        Theme theme(dir.path(), nullptr, command);
        QCOMPARE(theme.radius(), 0);
        QVERIFY(write(response, "{\"int\":6}"));
        QTRY_COMPARE(theme.radius(), 6);
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Save").isNull());
    }

    void translatorSpeaksRussian()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "ru\n");
        write(dir.path() + "/ru.json", R"({"Settings": "Настройки"})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("ru"));
        QCOMPARE(translator.translate("Main", "Settings"), QString("Настройки"));
    }
};

QTEST_MAIN(OrbitTests)
#include "orbit_tests.moc"
