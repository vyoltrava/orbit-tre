mod config;
mod orbit;
mod input;
mod icons;
mod launcher;
mod settings;

use anyhow::Result;
use gtk4::prelude::*;
use crate::config::Config;
use crate::input::hotkey::spawn_shift_lmb_grab;
use crate::orbit::state::{OrbitItem, OrbitState};
use crate::orbit::window::OrbitWindow;
use crate::settings::SettingsWindow;
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

fn main() -> Result<()> {
    env_logger::init();

    // Инициализируем GTK до создания приложения
    gtk4::init().expect("GTK init failed");

    let app = gtk4::Application::builder()
        .application_id("com.vyol.orbit-dock")
        .build();

    let config = Rc::new(RefCell::new(Config::load()));
    let state = Rc::new(RefCell::new(OrbitState::new(Rc::clone(&config))));

    // Окно настроек
    let settings = Rc::new(SettingsWindow::new(&app, Rc::clone(&config)));

    // Тестовая орбита с пунктами (из референса)
    {
        let mut s = state.borrow_mut();
        let main_page = vec![
            OrbitItem::new("home", "Главная", "true", "home"),
            OrbitItem::new("messages", "Сообщения", "true", "message-square"),
            OrbitItem::new("notifications", "Уведомления", "true", "bell"),
            OrbitItem::new("bookmarks", "Закладки", "true", "bookmark"),
            OrbitItem::new("updates", "Обновления", "true", "satellite"),
            OrbitItem::new("profile", "Профиль", "true", "user-plus"),
            OrbitItem::new("settings", "Настройки", "true", "settings"),
            OrbitItem::new("rules", "Правила", "true", "shield"),
            OrbitItem::new("bugs", "Баги", "true", "bug"),
            OrbitItem::new("support", "Поддержка", "true", "headphones"),
            OrbitItem::new("palette", "Палитра", "true", "palette"),
            OrbitItem::new("logout", "Выход", "true", "logout"),
        ];
        s.pages.push(main_page);
    }

    // Флаг от evdev-потока к GTK основному потоку (Shift+ЛКМ нажат)
    let trigger = Arc::new(AtomicBool::new(false));
    let trigger_for_evdev = Arc::clone(&trigger);
    let trigger_for_gtk = Arc::clone(&trigger);

    spawn_shift_lmb_grab(move || {
        trigger_for_evdev.store(true, Ordering::SeqCst);
    });

    // Окно орбиты — создаём после startup, храним в Rc<RefCell<Option<...>>>
    let window_slot: Rc<RefCell<Option<Rc<OrbitWindow>>>> = Rc::new(RefCell::new(None));

    app.connect_activate(move |app| {
        log::info!("connect_activate: creating orbit window");
        let window = Rc::new(OrbitWindow::new(app, Rc::clone(&state)));
        app.add_window(&window.window);
        *window_slot.borrow_mut() = Some(Rc::clone(&window));

        // Кнопка "Настройки" в орбите открывает окно конфига
        let settings_for_cb = Rc::clone(&settings);
        window.settings_cb.borrow_mut().replace(Box::new(move || {
            settings_for_cb.show();
        }));

        // Показываем орбиту при активации приложения (для теста)
        window.show_at(960.0, 540.0, 1920.0, 1080.0);

        // Проверяем флаг от evdev: Shift+ЛКМ нажал — открываем орбиту под курсором
        let window_hotkey = Rc::clone(&window);
        let trigger_gtk = Arc::clone(&trigger_for_gtk);
        gtk4::glib::timeout_add_local(std::time::Duration::from_millis(100), move || {
            if trigger_gtk.swap(false, Ordering::SeqCst) {
                // Временная заглушка: позиция курсора и размер монитора хардкодятся.
                window_hotkey.show_at(960.0, 540.0, 1920.0, 1080.0);
            }
            gtk4::glib::ControlFlow::Continue
        });
    });

    app.run();

    Ok(())
}
