use crate::config::Config;
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Clone, Copy, Debug)]
pub struct Vec2 {
    pub x: f64,
    pub y: f64,
}

impl Vec2 {
    pub fn dist(self, other: Vec2) -> f64 {
        ((self.x - other.x).powi(2) + (self.y - other.y).powi(2)).sqrt()
    }
}

#[derive(Debug, Clone)]
pub struct OrbitItem {
    pub id: String,
    pub label: String,
    pub exec: String,
    pub lucide_name: String,
    pub use_app_icon: bool,
    pub running: bool,
    pub page: String,
    pub folder: Option<String>,
}

impl OrbitItem {
    pub fn new(id: &str, label: &str, exec: &str, lucide_name: &str) -> Self {
        Self {
            id: id.to_string(),
            label: label.to_string(),
            exec: exec.to_string(),
            lucide_name: lucide_name.to_string(),
            use_app_icon: false,
            running: false,
            page: "main".to_string(),
            folder: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct OrbitState {
    pub config: Rc<RefCell<Config>>,
    pub opened: bool,
    pub hovered_idx: Option<usize>,
    pub hover_progress: f64,
    pub current_page: usize,
    pub pages: Vec<Vec<OrbitItem>>,
    pub center_x: f64,
    pub center_y: f64,
    pub full_circle: bool,
}

impl OrbitState {
    pub fn new(config: Rc<RefCell<Config>>) -> Self {
        Self {
            config,
            opened: false,
            hovered_idx: None,
            hover_progress: 0.0,
            current_page: 0,
            pages: vec![],
            center_x: 0.0,
            center_y: 0.0,
            full_circle: false,
        }
    }

    pub fn current_items(&self) -> &[OrbitItem] {
        self.pages.get(self.current_page).map(|v| v.as_slice()).unwrap_or(&[])
    }

    pub fn total(&self) -> usize {
        self.current_items().len()
    }

    pub fn selected_exec(&self) -> Option<String> {
        self.hovered_idx
            .and_then(|i| self.current_items().get(i))
            .map(|item| item.exec.clone())
    }

    pub fn set_hovered(&mut self, idx: Option<usize>) {
        self.hovered_idx = idx;
        self.hover_progress = if idx.is_some() { 1.0 } else { 0.0 };
    }

    pub fn open(&mut self, cx: f64, cy: f64, full_circle: bool) {
        self.opened = true;
        self.center_x = cx;
        self.center_y = cy;
        self.full_circle = full_circle;
        self.hovered_idx = None;
        self.hover_progress = 0.0;
    }

    pub fn close(&mut self) {
        self.opened = false;
        self.hovered_idx = None;
        self.hover_progress = 0.0;
    }
}
