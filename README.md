# Orbit Dock

**Standalone radial application launcher for Hyprland.** Written in Rust + GTK4.
Opens a ring of cells around the pointer with **Shift + Left Click**.

## Install (Arch Linux)

```sh
git clone https://github.com/vyoltrava/orbit-tre.git
cd orbit-tre/orbit-dock
./bin/install
```

`makepkg` builds and installs the package, then sets up the Hyprland binding.

## Usage

- **Shift + Left Click** — open orbit under the pointer. Press again to close.
- Click a cell — launch the app. **Escape** or click outside — close.
- Settings open from the **"Настройки"** cell. Saved to `~/.config/orbit-dock/config.json`.

## Hyprland binding

The installer adds this to `~/.config/hypr/bindings.lua`:

```
bindm = $mainMod, SHIFT, mouse:272, exec, orbit-dock
```

Then runs `hyprctl reload`. If you prefer to set it manually:

```sh
orbit-dock setup-hyprland-bind
# or edit ~/.config/hypr/bindings.lua yourself, then hyprctl reload
```

## Build without installing

```sh
./bin/build
./target/release/orbit-dock
```

## Tests

```sh
./bin/test
```

## Config

`~/.config/orbit-dock/config.json` — trigger, radii, accent color, opacity, icon size, pages.

## License

MIT
