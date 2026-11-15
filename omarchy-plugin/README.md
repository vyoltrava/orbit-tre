# Orbit for Omarchy

Orbit is a native Quickshell plugin that uses Omarchy's running shell instead
of starting another application process. It keeps the existing radial menu,
pointer-centered opening, nested folders, original Orbit/back icons, animated
hover line and spark, and settings editor.

## Install

Install the repository as a plugin:

```sh
omarchy plugin add https://github.com/vyoltrava/orbit-tre.git --enable
omarchy bar put vyoltrava.orbit --section left
```

Open Orbit with Shift+Left Click by default. Click the center of the ring to
open settings. The settings window can change the activation shortcut, edit
the app and folder layout, search installed applications, choose icons, and
reorder or remove cells. Appearance settings include custom menu colors, full,
reduced, or disabled animation, and a single toggle for all item names. Changes
are saved automatically; no manual config editing is needed.

The plugin reads and preserves the existing Orbit menu, so switching from the
standalone version keeps the current applications and folders.

## Validate

```sh
omarchy plugin validate .
```
