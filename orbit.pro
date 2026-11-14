QT += core gui qml quick quickcontrols2 svg

CONFIG += c++17 release
TARGET = orbit
TEMPLATE = app

QML_ROOT = src

HEADERS += \
    src/backend.h \
    src/iconprovider.h \
    src/theme.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/iconprovider.cpp \
    src/theme.cpp \
    src/translator.cpp

RESOURCES += src/resources.qrc
