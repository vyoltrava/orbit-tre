use crate::config::Config;
use crate::orbit::geometry::Geometry;
use crate::orbit::hit::hit_icon;
use crate::orbit::state::{OrbitState, Vec2};
use crate::launcher::launch;
use gtk4::prelude::*;
use gtk4::gdk::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;

const CSS_BASE: &str = r#"
.orbit-button {
    border-radius: 9999px;
    border: 1px solid rgba(255,255,255,0.15);
    background: rgba(34,34,42,0.95);
    box-shadow: 0 4px 20px rgba(0,0,0,0.4);
    padding: 0;
    min-width: 44px;
    min-height: 44px;
    transition: all 150ms ease;
    opacity: 0;
}
.orbit-button:hover,
.orbit-button.active {
    min-width: 56px;
    min-height: 56px;
    opacity: 1;
}
.orbit-button:active {
    background: rgba(255,255,255,0.1);
}
.orbit-button.visible {
    opacity: 1;
}
.orbit-label {
    color: rgba(255,255,255,0.85);
    font-size: 10px;
    font-weight: 600;
}
"#;

pub struct OrbitWindow {
    pub window: gtk4::ApplicationWindow,
    fixed: gtk4::Fixed,
    state: Rc<RefCell<OrbitState>>,
    buttons: Rc<RefCell<Vec<gtk4::Button>>>,
    pub settings_cb: Rc<RefCell<Option<Box<dyn Fn()>>>>,
}

impl OrbitWindow {
    pub fn new(app: &gtk4::Application, state: Rc<RefCell<OrbitState>>) -> Self {
        let window = gtk4::ApplicationWindow::new(app);
        window.set_decorated(false);
        window.set_default_size(400, 400);
        window.set_resizable(false);
        window.set_opacity(1.0);

        let fixed = gtk4::Fixed::new();
        window.set_child(Some(&fixed));

        // --- Escape = отмена ---
        let state_key = Rc::clone(&state);
        let window_key = window.clone();
        let key_controller = gtk4::EventControllerKey::new();
        key_controller.connect_key_pressed(move |_, keyval, _, _| {
            if keyval == gtk4::gdk::Key::Escape {
                let mut s = state_key.borrow_mut();
                if s.opened {
                    s.close();
                    window_key.hide();
                }
                gtk4::glib::Propagation::Stop
            } else {
                gtk4::glib::Propagation::Proceed
            }
        });
        window.add_controller(key_controller);

        Self {
            window,
            fixed,
            state,
            buttons: Rc::new(RefCell::new(Vec::new())),
            settings_cb: Rc::new(RefCell::new(None)),
        }
    }

    /// (Пере)загружает CSS с акцентным цветом из конфига.
    pub fn refresh_css(&self, accent: &str) {
        let css = format!(
            r#"{}
.orbit-button:hover,
.orbit-button.active {{
    background: {accent};
    border-color: {accent};
    box-shadow: 0 0 28px rgba(139,92,246,0.55);
}}
.orbit-button:active {{
    background: {accent};
}}
.orbit-button.visible {{
    opacity: 1;
}}
"#,
            CSS_BASE,
            accent = accent
        );
        let provider = gtk4::CssProvider::new();
        provider.load_from_data(&css);
        if let Some(display) = gtk4::gdk::Display::default() {
            gtk4::style_context_add_provider_for_display(
                &display,
                &provider,
                gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
            );
        }
    }

    pub fn show_at(&self, cx: f64, cy: f64, sw: f64, sh: f64) {
        let mut s = self.state.borrow_mut();
        s.open(cx, cy, true);
        drop(s);

        // Убираем старые кнопки
        let mut buttons = self.buttons.borrow_mut();
        for b in buttons.iter() {
            self.fixed.remove(b);
        }
        buttons.clear();
        drop(buttons);

        // Геометрия
        let (nx, ny, pad, outer_radius) = {
            let s = self.state.borrow();
            let cfg = s.config.borrow();
            let geo = Geometry::new(Vec2 { x: cx, y: cy }, &cfg, s.full_circle);
            let (nx, ny) = geo.clamp_to_viewport(cx, cy, sw, sh);
            (nx, ny, cfg.outer_radius + 12.0, cfg.outer_radius)
        };

        let size = (outer_radius * 2.0 + pad * 2.0) as i32;
        let win_size = size.max(400);
        self.window.set_default_size(win_size, win_size);

        // Позиция окна: верхний левый угол так, чтобы центр был в (nx, ny)
        let win_x = nx - win_size as f64 / 2.0;
        let win_y = ny - win_size as f64 / 2.0;
        // В GTK4 позиция окна управляется Wayland-композитором, move() нет —
        // окно pojawiтся там, где compositor решит, после present().

        // Создаём кнопки
        let items = self.state.borrow().current_items().to_vec();
        let total = items.len();
        let center = Vec2 { x: win_size as f64 / 2.0, y: win_size as f64 / 2.0 };
        let cfg = self.state.borrow().config.borrow().clone();

        // Применяем акцентный цвет из конфига к CSS (не забиваем на тему).
        self.refresh_css(&cfg.accent_color);

        let mut new_buttons = Vec::new();
        for (i, item) in items.iter().enumerate() {
            let pos = Geometry::new(center, &cfg, true).icon_pos(i, total);

            let button = gtk4::Button::new();
            button.add_css_class("orbit-button");

            // Иконка lucide, окрашена в цвет акцента из конфига.
            let img = gtk4::Image::new();
            if let Some(pb) = crate::icons::lucide::load_pixbuf(&item.lucide_name, 24, &cfg.accent_color) {
                img.set_from_pixbuf(Some(&pb));
            }
            button.set_child(Some(&img));

            // Метка
            let label = gtk4::Label::new(Some(&item.label));
            label.add_css_class("orbit-label");

            self.fixed.put(&button, pos.x - 22.0, pos.y - 22.0);

            // Клик
            let state_click = Rc::clone(&self.state);
            let window_click = self.window.clone();
            let exec_cmd = item.exec.clone();
            let item_id = item.id.clone();
            let settings_cb = Rc::clone(&self.settings_cb);
            button.connect_clicked(move |_| {
                let mut s = state_click.borrow_mut();
                s.close();
                drop(s);
                window_click.hide();
                // Пункт "Настройки" открывает окно конфига через callback
                if item_id == "settings" {
                    if let Some(cb) = settings_cb.borrow().as_ref() {
                        cb();
                    }
                    return;
                }
                if let Err(e) = launch(&exec_cmd) {
                    log::error!("failed to launch {}: {}", exec_cmd, e);
                }
            });

            new_buttons.push(button);
        }

        // Анимация появления: staggered i*25ms
        let buttons_ref = Rc::clone(&self.buttons);
        for (i, button) in new_buttons.iter().enumerate() {
            let b = button.clone();
            let buttons_weak = Rc::clone(&buttons_ref);
            gtk4::glib::timeout_add_local(std::time::Duration::from_millis(25 * i as u64), move || {
                b.add_css_class("visible");
                b.set_opacity(1.0);
                let _ = buttons_weak;
                gtk4::glib::ControlFlow::Break
            });
        }

        *self.buttons.borrow_mut() = new_buttons;

        self.window.present();
        self.window.show();
    }

    pub fn hide(&self) {
        let mut s = self.state.borrow_mut();
        s.close();
        drop(s);
        self.window.hide();
    }
}
