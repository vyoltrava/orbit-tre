// IconProvider — serves app icons (from the icon theme) and the built-in
// folder/gear/back glyphs to QML as image://icons/<name>.
//
// "image://icons/circle:<name>" returns the same icon clipped to a circle,
// so square app icons sit exactly inside the round cell and never poke out.
#pragma once

#include <QQuickImageProvider>

class IconProvider : public QQuickImageProvider {
public:
    explicit IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
