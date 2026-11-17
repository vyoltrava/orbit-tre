use crate::config::Config;
use crate::orbit::state::Vec2;
use std::f64::consts::PI;

// Константы из веб-референса (lucide orbit)
pub const INNER_RADIUS_BASE: f64 = 135.0;
pub const OUTER_RADIUS_BASE: f64 = 215.0;
pub const FREE_INNER_RADIUS_BASE: f64 = 95.0;
pub const FREE_OUTER_RADIUS_BASE: f64 = 150.0;
pub const SELECT_ENTER: f64 = 56.0;
pub const PICK_DIST: f64 = 60.0;
pub const PAGE_SWIPE: f64 = 30.0;

pub struct Geometry {
    pub center: Vec2,
    pub inner_radius: f64,
    pub outer_radius: f64,
    pub full_circle: bool,
}

impl Geometry {
    pub fn new(center: Vec2, config: &Config, full_circle: bool) -> Self {
        let scale = config.scale_factor;
        let (inner, outer) = if full_circle {
            (FREE_INNER_RADIUS_BASE, FREE_OUTER_RADIUS_BASE)
        } else {
            (INNER_RADIUS_BASE, OUTER_RADIUS_BASE)
        };
        Self {
            center,
            inner_radius: inner * scale,
            outer_radius: outer * scale,
            full_circle,
        }
    }

    /// Позиция иконки по индексу.
    /// В обычном режиме — полудуга (как в вебе), в свободной — полный круг вокруг точки зажима.
    pub fn icon_pos(&self, index: usize, total: usize) -> Vec2 {
        let total = total.max(1);
        let layer = if index % 2 == 0 {
            self.inner_radius
        } else {
            self.outer_radius
        };

        let step = if self.full_circle {
            (PI * 2.0) / total as f64
        } else {
            (PI) / (total as f64 - 1.0).max(1.0)
        };

        let start_angle = -PI / 2.0; // начало сверху
        let angle = start_angle + index as f64 * step;

        let (sin, cos) = angle.sin_cos();
        Vec2 {
            x: self.center.x + cos * layer,
            y: self.center.y + sin * layer,
        }
    }

    /// Поджать центр орбиты к вьюпорту, чтобы круг не вылезал за экран.
    pub fn clamp_to_viewport(&self, cx: f64, cy: f64, sw: f64, sh: f64) -> (f64, f64) {
        let pad = self.outer_radius + 12.0;
        let nx = cx.clamp(pad, sw - pad);
        let ny = cy.clamp(pad, sh - pad);
        (nx, ny)
    }

    /// Режим выбора активен? (курсор ушёл от центра больше SELECT_ENTER)
    pub fn is_select_mode(&self, cursor: Vec2) -> bool {
        self.center.dist(cursor) > SELECT_ENTER * self.inner_radius / INNER_RADIUS_BASE
    }
}
