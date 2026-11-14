// IconProvider — serves app icons (from the icon theme) and the built-in
// folder/gear/back glyphs to QML as image://icons/<name>.
#pragma once

#include <QQuickImageProvider>

class IconProvider : public QQuickImageProvider {
public:
    explicit IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
