#include "iconprovider.h"

#include <QIcon>
#include <QPainter>
#include <QPainterPath>
#include <QPixmap>
#include <QUrl>

QPixmap IconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int side = requestedSize.isValid() && requestedSize.width() > 0 ? requestedSize.width() : 48;
    // The icon name travels percent-encoded, because theme names may carry
    // characters QML's image URL would mangle.
    const bool circle = id.startsWith(QLatin1String("circle:"));
    const QString encoded = circle ? id.mid(7) : id;
    const QString name = QUrl::fromPercentEncoding(encoded.toUtf8());
    if (size)
        *size = QSize(side, side);

    const QPixmap pixmap = QIcon::fromTheme(name, QIcon::fromTheme("application-x-executable"))
                               .pixmap(side, side);
    if (!circle)
        return pixmap;

    // Clip the square icon to the round cell: corners become transparent, so
    // even full-bleed square icons stay inside the circle.
    QPixmap clipped(side, side);
    clipped.fill(Qt::transparent);
    QPainter painter(&clipped);
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    QPainterPath circlePath;
    circlePath.addEllipse(QRectF(0, 0, side, side));
    painter.setClipPath(circlePath);
    painter.drawPixmap(QRectF(0, 0, side, side), pixmap, pixmap.rect());
    painter.end();
    return clipped;
}
