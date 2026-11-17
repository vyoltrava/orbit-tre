use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub trigger_mouse: Vec<String>,
    pub trigger_keyboard: Vec<String>,
    pub open_under_cursor: bool,
    pub inner_radius: f64,
    pub outer_radius: f64,
    pub free_inner_radius: f64,
    pub free_outer_radius: f64,
    pub accent_color: String,
    pub line_style: String,
    pub line_pulse: bool,
    pub ignore_input_fields: bool,
    pub ignore_fullscreen: bool,
    pub bg_opacity: f64,
    pub scale_factor: f64,
    pub icon_size: f64,
    pub use_app_icons: bool,
    pub pages: Vec<Page>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Page {
    pub id: String,
    pub name: String,
    pub items: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            trigger_mouse: vec!["Shift".into(), "Button1".into()],
            trigger_keyboard: vec!["Super".into(), "Space".into()],
            open_under_cursor: true,
            inner_radius: 135.0,
            outer_radius: 215.0,
            free_inner_radius: 95.0,
            free_outer_radius: 150.0,
            accent_color: "#8b5cf6".into(),
            line_style: "bezier".into(),
            line_pulse: true,
            ignore_input_fields: true,
            ignore_fullscreen: true,
            bg_opacity: 0.75,
            scale_factor: 1.0,
            icon_size: 48.0,
            use_app_icons: true,
            pages: vec![],
        }
    }
}

impl Config {
    pub fn load() -> Self {
        let path = Self::path();
        if let Ok(c) = fs::read_to_string(&path) {
            serde_json::from_str(&c).unwrap_or_default()
        } else {
            Self::default()
        }
    }

    pub fn path() -> PathBuf {
        dirs::config_dir()
            .unwrap_or_else(|| std::env::temp_dir())
            .join("orbit-dock/config.json")
    }

    pub fn save(&self) -> std::io::Result<()> {
        let path = Self::path();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(path, serde_json::to_string_pretty(self).unwrap())?;
        Ok(())
    }
}
