#include "iconprovider.h"

#include <QIcon>
#include <QPainter>
#include <QUrl>

QPixmap IconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) {
    const int side = requestedSize.isValid() && requestedSize.width() > 0 ? requestedSize.width() : 48;
    // The icon name travels percent-encoded, because theme names may carry
    // characters QML's image URL would mangle.
    const QString name = QUrl::fromPercentEncoding(id.toUtf8());
    if (size)
        *size = QSize(side, side);

    const QPixmap pixmap = QIcon::fromTheme(name, QIcon::fromTheme("application-x-executable"))
                               .pixmap(side, side);
    return pixmap;
}
