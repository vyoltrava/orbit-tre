use crate::orbit::geometry::{
    Geometry, INNER_RADIUS_BASE, OUTER_RADIUS_BASE, PICK_DIST, SELECT_ENTER,
};
use crate::orbit::state::{OrbitState, Vec2};
use crate::config::Config;

// Найти ближайшую иконку к курсора в режиме выбора.
// Если курсор ещё не ушёл от центра на SELECT_ENTER — возвращаем None (не в режиме выбора).
pub fn hit_icon(state: &OrbitState, cursor: Vec2) -> Option<usize> {
    let cfg = state.config.borrow();
    let total = state.total();
    if total == 0 {
        return None;
    }

    // Центр орбиты — центр окна (DrawingArea)
    let center = Vec2 {
        x: state.center_x,
        y: state.center_y,
    };

    let geo = Geometry::new(center, &cfg, state.full_circle);

    // Ещё не вошли в режим выбора
    if !geo.is_select_mode(cursor) {
        return None;
    }

    // Ближайшая иконка
    let mut best_idx: Option<usize> = None;
    let mut best_dist = f64::INFINITY;

    for i in 0..total {
        let pos = geo.icon_pos(i, total);
        let d = pos.dist(cursor);
        if d < best_dist {
            best_dist = d;
            best_idx = Some(i);
        }
    }

    // Радиус попадания масштабируется с inner_radius (как в вебе: PICK_DIST от базы)
    let pick_radius = PICK_DIST * geo.inner_radius / INNER_RADIUS_BASE;
    if best_dist <= pick_radius {
        best_idx
    } else {
        None
    }
}
