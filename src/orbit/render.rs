use crate::config::Config;
use crate::icons::lucide::draw_icon;
use crate::orbit::geometry::Geometry;
use crate::orbit::state::{OrbitState, Vec2};
use gtk4::cairo::{self, Context};
use std::f64::consts::PI;

pub fn draw_frame(
    state: &OrbitState,
    cr: &Context,
    width: f64,
    height: f64,
) {
    let cfg = state.config.borrow();
    let geo = Geometry::new(
        Vec2 { x: width / 2.0, y: height / 2.0 },
        &cfg,
        state.full_circle,
    );
    let items = state.current_items();
    let total = items.len();
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0);

    // ---------- фон орбиты ----------
    cr.set_source_rgba(0.06, 0.06, 0.08, cfg.bg_opacity);
    cr.arc(width / 2.0, height / 2.0, cfg.outer_radius + 24.0, 0.0, 2.0 * PI);
    cr.fill().ok();

    if total == 0 {
        return;
    }

    // ---------- линии к наведённой иконке ----------
    if let Some(hovered) = state.hovered_idx {
        let target = geo.icon_pos(hovered, total);
        let center = geo.center;
        let pulse = (now * (2.0 * PI / 0.75)).sin(); // период 750мс
        let width_l = 2.0 + pulse.abs() * 1.0;
        let alpha = 0.55 + pulse.abs() * 0.35;

        let accent = parse_hex(&cfg.accent_color);
        let dx = target.x - center.x;
        let dy = target.y - center.y;
        let cp_x = (center.x + target.x) / 2.0 - dy * 0.18;
        let cp_y = (center.y + target.y) / 2.0 + dx * 0.18;

        let end_x = center.x + (target.x - center.x) * state.hover_progress;
        let end_y = center.y + (target.y - center.y) * state.hover_progress;

        // градиент от центра к иконке
        let grad = cairo::LinearGradient::new(center.x, center.y, end_x, end_y);
        grad.add_color_stop_rgba(0.0, accent.0, accent.1, accent.2, 0.0);
        grad.add_color_stop_rgba(1.0, accent.0, accent.1, accent.2, alpha);
        cr.set_source(&grad);

        cr.set_line_width(width_l);
        cr.set_line_cap(cairo::LineCap::Round);
        cr.move_to(center.x, center.y);
        cr.curve_to(cp_x, cp_y, end_x, end_y, end_x, end_y);
        cr.stroke().ok();

        // кольцо в конце (дышит)
        let ring_r = 5.0 + pulse.abs() * 2.0;
        cr.set_source_rgba(accent.0, accent.1, accent.2, alpha);
        cr.arc(end_x, end_y, ring_r, 0.0, 2.0 * PI);
        cr.fill().ok();

        // glow
        cr.set_source_rgba(accent.0, accent.1, accent.2, alpha * 0.35);
        cr.arc(end_x, end_y, ring_r + 6.0, 0.0, 2.0 * PI);
        cr.stroke().ok();
    }

    // ---------- иконки ----------
    for (i, item) in items.iter().enumerate() {
        let pos = geo.icon_pos(i, total);
        let hovered = state.hovered_idx == Some(i);
        let scale = if hovered { 1.35 } else { 1.0 };
        let icon_sz = cfg.icon_size * scale;

        // индикатор запущенной (точка под иконкой)
        if item.running {
            cr.set_source_rgba(0.0, 0.9, 0.6, 0.9);
            cr.arc(pos.x, pos.y + icon_sz * 0.6, 5.0, 0.0, 2.0 * PI);
            cr.fill().ok();
        }

        // иконка (lucide, окрашена в цвет акцента из конфига/темы)
        let icon_draw_x = pos.x;
        let icon_draw_y = pos.y;
        draw_icon(cr, &item.lucide_name, icon_draw_x, icon_draw_y, icon_sz, &cfg.accent_color, cfg.scale_factor);

        // метка под иконкой
        cr.set_source_rgb(1.0, 1.0, 1.0);
        cr.set_font_size(11.0 * cfg.scale_factor);
        let text_w = cr
            .text_extents(&item.label)
            .ok()
            .map(|e| e.width())
            .unwrap_or(0.0);
        cr.move_to(
            pos.x - text_w / 2.0,
            pos.y + icon_sz * 0.5 + 16.0,
        );
        cr.show_text(&item.label).ok();
    }

    // ---------- индикатор страниц ----------
    draw_page_dots(cr, state.pages.len(), state.current_page, &cfg, geo.center);
}

fn draw_page_dots(cr: &Context, pages: usize, active: usize, cfg: &Config, center: Vec2) {
    if pages <= 1 {
        return;
    }
    let dot_r = 5.0 * cfg.scale_factor;
    let gap = 12.0 * cfg.scale_factor;
    let total_h = (pages as f64) * gap;
    let start_y = center.y - total_h / 2.0 + dot_r;

    for i in 0..pages {
        let active_flag = i == active;
        cr.set_source_rgba(
            if active_flag { 1.0 } else { 0.45 },
            if active_flag { 1.0 } else { 0.45 },
            if active_flag { 1.0 } else { 0.45 },
            if active_flag { 1.0 } else { 0.45 },
        );
        cr.arc(
            center.x + 34.0 * cfg.scale_factor,
            start_y + i as f64 * gap,
            dot_r,
            0.0,
            2.0 * PI,
        );
        cr.fill().ok();
    }
}

fn parse_hex(hex: &str) -> (f64, f64, f64, f64) {
    let h = hex.trim_start_matches('#');
    let r = u8::from_str_radix(&h[0..2], 16).unwrap_or(139) as f64 / 255.0;
    let g = u8::from_str_radix(&h[2..4], 16).unwrap_or(92) as f64 / 255.0;
    let b = u8::from_str_radix(&h[4..6], 16).unwrap_or(202) as f64 / 255.0;
    (r, g, b, 1.0)
}
