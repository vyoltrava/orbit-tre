# Orbit

**A radial application launcher for Omarchy, built as a native Quickshell
plugin.** Orbit opens around your pointer, launches apps from a compact ring,
and lets folders open into their own nested orbits.

![Orbit's radial menu](docs/orbit-menu.png)

## Features

- Pointer-centered radial menu that runs inside Omarchy's existing shell.
- Add installed apps, create folders, and nest folders as needed.
- Edit names, commands, and icons; reorder or remove items from the settings
  window.
- Customize menu colors, choose full, reduced, or disabled animation, and hide
  all item names with one switch.
- Automatically manages its Hyprland activation binding.
- Reuses the existing menu at `~/.config/orbit/menu.json`.

## Install on Omarchy

Add and enable the plugin, then place its launcher in the bar:

```sh
omarchy plugin add https://github.com/vyoltrava/orbit-tre.git --enable
omarchy bar put vyoltrava.orbit --section left
```

By default, **Shift + Left Click** opens Orbit at the pointer. Click the center
to open settings; inside a folder, the center button returns to the parent
orbit. Press **Escape** or click outside the menu to close it.

## Configure

Open settings by clicking the center of the root orbit. The in-window editor
can change the activation shortcut, search and add installed applications,
create folders, choose icons, edit commands, and reorder or remove items.
Appearance controls let you set the background, selected background, text,
accent, and border colors; select an animation preset; and toggle item names.
Changes are saved automatically.

Orbit stores its menu and preferences here:

| File | Contents |
| --- | --- |
| `~/.config/orbit/menu.json` | Applications and folder layout |
| `~/.config/orbit/config.json` | Activation shortcut and appearance settings |
| `~/.config/hypr/bindings.lua` | Orbit's managed activation binding |

The plugin preserves the existing `menu.json`, so switching from the standalone
launcher keeps your current applications and folders.

## Development

Validate the plugin and run its focused model tests:

```sh
omarchy plugin validate .
node tests/orbit_plugin_model.js
```

The repository also retains the standalone Qt application source. Its build
and test helpers are `./bin/build` and `./bin/test`.

## License

MIT — see [LICENSE](LICENSE).
