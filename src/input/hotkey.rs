use evdev;
use std::thread;

// Коды клавиш evdev (linux/input-event-codes.h)
const KEY_LEFTSHIFT: u16 = 42;
const KEY_RIGHTSHIFT: u16 = 54;
const KEY_BTN_LEFT: u16 = 272; // 0x110

// Глобальный триггер Shift + ЛКМ через evdev grab.
// Требует, чтобы пользователь был в группе `input` (или запуск от root).
pub fn spawn_shift_lmb_grab<F>(on_trigger: F)
where
    F: Fn() + Send + 'static,
{
    thread::spawn(move || {
        for mut device in evdev::enumerate() {
            let name = device.name().unwrap_or_default();
            if !name.contains("Mouse")
                && !name.contains("Touchpad")
                && !name.contains("Keyboard")
                && !name.contains("keyboard")
            {
                continue;
            }
            if device.grab().is_err() {
                continue;
            }

            let mut shift_pressed = false;
            let events = match device.fetch_events() {
                Ok(e) => e,
                Err(_) => continue,
            };
            for event in events {
                if event.event_type() == evdev::EventType::KEY {
                    let code: u16 = event.code().into();
                    if code == KEY_LEFTSHIFT || code == KEY_RIGHTSHIFT {
                        shift_pressed = event.value() == 1;
                    } else if code == KEY_BTN_LEFT {
                        if event.value() == 1 && shift_pressed {
                            on_trigger();
                        }
                    }
                }
            }
        }
    });
}
