fn main() {
    // В дальнейшем здесь будет встраивание lucide SVG из resources/lucide
    println!("cargo:rerun-if-changed=resources/lucide");
}
