use crate::config::Config;
use gtk4::prelude::*;
use gtk4::{
    ApplicationWindow, Box, Button, CheckButton, Entry, Label, Orientation,
};
use std::cell::RefCell;
use std::rc::Rc;

pub struct SettingsWindow {
    window: ApplicationWindow,
    config: Rc<RefCell<Config>>,
}

impl SettingsWindow {
    pub fn new(app: &gtk4::Application, config: Rc<RefCell<Config>>) -> Self {
        let window = ApplicationWindow::new(app);
        window.set_title(Some("Настройки Orbit Dock"));
        window.set_default_size(420, 320);
        window.set_modal(true);

        let box_ = Box::new(Orientation::Vertical, 12);
        box_.set_margin_top(24);
        box_.set_margin_bottom(24);
        box_.set_margin_start(24);
        box_.set_margin_end(24);

        // ---------- Акцентный цвет ----------
        let color_label = Label::new(Some("Акцентный цвет (HEX, например #8b5cf6):"));
        color_label.set_halign(gtk4::Align::Start);
        box_.append(&color_label);

        let color_entry = Entry::new();
        color_entry.set_text(&config.borrow().accent_color);
        color_entry.set_hexpand(true);
        let cfg_entry = Rc::clone(&config);
        color_entry.connect_activate(move |e| {
            let text = e.text().to_string();
            let mut cfg = cfg_entry.borrow_mut();
            cfg.accent_color = text;
            let _ = cfg.save();
        });
        box_.append(&color_entry);

        // ---------- Иконки приложений ----------
        let use_app_label = Label::new(Some("Источник иконок:"));
        use_app_label.set_halign(gtk4::Align::Start);
        box_.append(&use_app_label);

        let use_app = CheckButton::with_label("Использовать иконки приложений из системной темы (Papirus / Adwaita)");
        use_app.set_active(config.borrow().use_app_icons);
        let cfg_app = Rc::clone(&config);
        use_app.connect_toggled(move |b| {
            let mut cfg = cfg_app.borrow_mut();
            cfg.use_app_icons = b.is_active();
            let _ = cfg.save();
        });
        box_.append(&use_app);

        // ---------- Кнопки ----------
        let btn_box = Box::new(Orientation::Horizontal, 8);
        btn_box.set_halign(gtk4::Align::End);
        btn_box.set_hexpand(true);

        let apply_btn = Button::with_label("Применить");
        let cfg_apply = Rc::clone(&config);
        apply_btn.connect_clicked(move |_| {
            let _ = cfg_apply.borrow().save();
        });
        btn_box.append(&apply_btn);

        let close_btn = Button::with_label("Закрыть");
        let window_clone = window.clone();
        close_btn.connect_clicked(move |_| {
            window_clone.hide();
        });
        btn_box.append(&close_btn);

        box_.append(&btn_box);

        window.set_child(Some(&box_));

        Self { window, config }
    }

    pub fn show(&self) {
        self.window.present();
    }
}
