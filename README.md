# Orbit

A radial launcher for Omarchy (Hyprland): one ring of cells around your
pointer. A cell is either a link to an app or a folder — clicking a folder
opens its own orbit, nested as deep as you like. The center of the ring is
Settings.

![Orbit menu](docs/orbit-menu.png)

![Settings](docs/orbit-settings.png)

## Use it

- **Shift + Left click** opens the orbit under the pointer (the default bind).
  Press the same combo again to close it.
- Click a cell to launch the app. Click a folder to fly its own ring out.
- **Escape**, or a click outside the ring, closes it.
- The orbit icon opens Settings at the root and goes back one level inside a folder.

The orbit follows the Omarchy accent and language live.

## Set it up

Open the settings from the center of the ring (or launch `Orbit` from the
launcher). There you can:

- **Change the activation combo** — press whatever you like: Shift+LMB,
  Super+O, F9… The Hyprland bind is rewritten and reloaded on the spot.
- **Edit the menu** — add installed applications, add folders, rename cells,
  borrow an icon from any installed app, reorder with ◀ ▶, remove cells.
  Every change is saved to `~/.config/orbit/menu.json` at once.

## Files

- `~/.config/orbit/menu.json` — the menu tree.
- `~/.config/orbit/config.json` — the activation combo.
- `~/.config/hypr/bindings.lua` — a managed block (`-- >>> orbit-menu`) with
  the bind and the window rules. Everything else in the file stays yours.

## Build and install

Orbit targets Arch Linux with Hyprland (including Omarchy). On the PC where you
want to install it, install `git` and `base-devel`, then clone this repository
and run the installer:

```sh
git clone https://github.com/vyoltrava/orbit-tre.git
cd orbit-tre
./bin/install
```

`makepkg` resolves the Qt and Hyprland dependencies, builds the package, and
asks for your password to install it. Launch **Orbit** from the app launcher.
On first launch, Orbit writes its activation bind. If Shift+LMB is already
taken, change the combo in Settings.

To build without installing, run `./bin/build`. To run the test suite, run
`./bin/test`.

## Keys

| Key | Action |
| --- | --- |
| Shift + LMB | Open / close the orbit (changeable) |
| Escape | Close, or leave settings |
| Click outside the ring | Close |

## Develop

```sh
bin/build   # qmake6 + make into build/orbit
bin/test    # Qt Test suite, offscreen
```

Licensed under the MIT license; the theme and translator follow Omacut and
Monologue (MIT, David Heinemeier Hansson).
