use gtk4::cairo::{self, Context};
use gtk4::gdk_pixbuf::Pixbuf;
use std::fs;
use std::io::Cursor;
use std::path::PathBuf;

/// Директория с lucide SVG
fn lucide_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("ORBIT_DOCK_LUCIDE_DIR") {
        return PathBuf::from(dir);
    }
    PathBuf::from("resources/lucide")
}

/// Читает lucide SVG и явно заменяет currentColor на заданный цвет.
/// Без этого librsvg может рендерить currentColor в неопределённый оттенок
/// (часто розовый/фиолетовый), и все иконки окрашиваются в один цвет.
fn svg_bytes_with_color(name: &str, color: &str) -> Option<Vec<u8>> {
    let svg_path = lucide_dir().join(format!("{name}.svg"));
    let svg = fs::read_to_string(&svg_path).ok()?;
    let svg = svg.replace("stroke=\"currentColor\"", &format!("stroke=\"{}\"", color));
    let svg = svg.replace("fill=\"currentColor\"", &format!("fill=\"{}\"", color));
    Some(svg.into_bytes())
}

/// Загружает lucide иконку как Pixbuf заданного размера и цвета.
pub fn load_pixbuf(name: &str, _size_px: i32, color: &str) -> Option<Pixbuf> {
    let bytes = svg_bytes_with_color(name, color)?;
    Pixbuf::from_read(Cursor::new(bytes)).ok()
}

/// Отрисовывает lucide иконку на cairo контексте в позиции (x, y) с заданным размером и цветом.
pub fn draw_icon(
    cr: &Context,
    name: &str,
    x: f64,
    y: f64,
    size: f64,
    color: &str,
    _scale_factor: f64,
) {
    let size_px = size as i32;
    let Some(pixbuf) = load_pixbuf(name, size_px, color) else {
        // Fallback: цветной квадрат, если иконка не найдена
        cr.set_source_rgb(0.6, 0.6, 0.6);
        cr.rectangle(x - size / 2.0, y - size / 2.0, size, size);
        cr.fill();
        return;
    };

    let width = pixbuf.width();
    let height = pixbuf.height();
    let rowstride = pixbuf.rowstride();
    let pixels = unsafe { pixbuf.pixels().to_vec() };

    let surface = match cairo::ImageSurface::create_for_data(
        pixels.to_vec(),
        cairo::Format::ARgb32,
        width,
        height,
        rowstride,
    ) {
        Ok(s) => s,
        Err(_) => {
            // Fallback
            cr.set_source_rgb(0.6, 0.6, 0.6);
            cr.rectangle(x - size / 2.0, y - size / 2.0, size, size);
            cr.fill();
            return;
        }
    };

    cr.set_source_surface(&surface, x - size / 2.0, y - size / 2.0);
    cr.paint();
}
