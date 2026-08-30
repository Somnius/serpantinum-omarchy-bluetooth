# Serpantinum Bluetooth for Omarchy

An animated, theme-aware Bluetooth widget for the Omarchy bar. This is an
unofficial clean-room implementation inspired by Serpantinum, not a source
port. Read [NOTICE.md](NOTICE.md) for provenance and rights notes.

## Features

- Shows unavailable, powered-off, enabled, and connected states in the bar.
- Opens an animated popup with adapter power, discovery, devices, pairing,
  connection, disconnection, battery percentage, and explicit failure text.
- Sorts connected devices first, then remembered devices, then new discoveries.
- Supports pointer and keyboard control.
- Starts discovery only for an open popup and stops the discovery session it
  owns on close or destruction.
- Handles missing BlueZ/default adapter and powered-off adapters without
  crashing or hiding the reason.

## Requirements

Omarchy Quattro 4.x with its bundled Quickshell and a BlueZ-compatible adapter.
There are **no additional packages, scripts, services, fonts, or install
hooks**. The plugin uses Omarchy's already installed `qs.Ui`/`qs.Commons`
components and Quickshell's native `Quickshell.Bluetooth` service.

If this panel reports that no adapter exists, first verify the host's normal
Omarchy Bluetooth setup; this plugin intentionally does not install, enable, or
modify system services.

## Install

After publication:

```sh
omarchy plugin add https://github.com/Somnius/serpantinum-omarchy-bluetooth --enable
```

Move the enabled widget if desired:

```sh
omarchy bar move somnius.serpantinum-bluetooth --section right
```

Never copy or edit files under `/usr/share/omarchy`; installed user plugins
belong under Omarchy's user plugin directory and hot-reload there.

## Configuration

Settings are inline fields on the widget's entry in
`~/.config/omarchy/shell.json`:

```json
{
  "id": "somnius.serpantinum-bluetooth",
  "autoScan": true,
  "showAddress": false,
  "reducedMotion": false
}
```

| Setting | Default | Meaning |
|---|---|---|
| `autoScan` | `true` | Scan while the popup is open and the adapter is enabled. |
| `showAddress` | `false` | Show hardware addresses instead of device status. |
| `reducedMotion` | `false` | Disable popup entrance and scanning-orbit animation. |

## Controls

| Input | Action |
|---|---|
| Left click bar icon | Open or close popup |
| Right click bar icon | Toggle adapter power |
| Click device / Enter / Space | Pair, connect, or disconnect |
| Up/Down or `j`/`k` | Select device |
| `b` | Toggle adapter power |
| Escape | Close popup |
| Tab / Shift+Tab | Switch compatible open bar panels |

Pair/connect/disconnect requests time out after 20 seconds, and power changes
after 5 seconds, producing a clear message on failure. BlueZ and the device
remain the source of truth; the UI never claims success until native state
changes.

## Discovery lifecycle

The popup records whether it initiated discovery. Closing it schedules a stop
after a short handoff window, while destruction attempts an immediate cleanup.
It does not stop an already-running discovery session that it did not start.
If BlueZ ends discovery while an auto-scanning popup remains open, scanning is
restarted after a bounded delay; the retry stops as soon as the popup closes.

## Development and verification

```sh
omarchy plugin validate .
node tests/model.test.js
qmllint -I /usr/share/omarchy/shell Bluetooth.qml
```

Live acceptance should cover: no adapter, power off/on, no devices, pairing a
new device, connecting a remembered device, disconnecting, timeout text,
repeated open/close, shell reload during discovery, multiple monitors, light
and dark themes, scaling, and reduced motion.

## Security and privacy

No device name or address is passed to a shell, no subprocess is launched, and
no network API is contacted. Bluetooth operations go directly through the
typed Quickshell/BlueZ objects already present in Omarchy.

## License

Original code is MIT licensed. Serpantinum projects and assets are not bundled
or relicensed; see [NOTICE.md](NOTICE.md).
