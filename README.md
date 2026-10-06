# 85HA Keyboard

A macOS app for remapping the 8BitDo 85HA using a clickable keyboard layout. Mappings are saved inside the keyboard and work over USB or wireless.

## Download

[Download the latest release](https://github.com/solid-pixel/8bitdo-85ha-keyboard/releases/latest), unzip it, and open **85HA Keyboard.app**.

Requires **Apple Silicon and macOS 13+**. This unofficial, experimental app is not notarized, so macOS may show a security warning.

## Use

1. Connect the keyboard by USB and set its selector to **OFF**.
2. Click a key, choose **Assign to**, and select its new action.
3. Click **Save to keyboard** and authorize the administrator prompt.
4. Turn the heart/profile light on to use your saved mappings.

Each save creates a backup and verifies the result. **Undo last save** restores the previous mapping; **Backups** opens the backup folder.

**Macros can be inspected, but saving and removal are disabled because replacement is unreliable.**

## Build

With Xcode Command Line Tools and Python 3.12+ installed:

```sh
python3 build.py
```

See [BUILD.md](BUILD.md) for details and [audit/MACROS.md](audit/MACROS.md) for macro investigation notes.

Uses [libusb](third_party/COPYING-libusb) and protocol research from [8bitdo-kbd-mapper](https://github.com/goncalor/8bitdo-kbd-mapper) and [8-retro-kbd-ctl](https://github.com/paulguy/8-retro-kbd-ctl).
