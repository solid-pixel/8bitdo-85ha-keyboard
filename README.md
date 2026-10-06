# 8BitDo 85HA Keyboard

A macOS app for remapping the 8BitDo 85HA using a clickable keyboard layout. Mappings are saved inside the keyboard and work over USB or wireless.

## Download

[Download the latest release](https://github.com/solid-pixel/8bitdo-85ha-keyboard/releases/latest), unzip it, and open **8BitDo 85HA Keyboard.app**.

Requires **Apple Silicon and macOS 13+**. This unofficial, experimental app is not notarized by Apple. If macOS says it cannot verify the app:

1. Click **Done** in the warning.
2. Open **System Settings → Privacy & Security** and scroll down.
3. Click **Open Anyway** beside the app's warning, authenticate, and confirm **Open**.

This adds an exception for this app. See [Apple's instructions](https://support.apple.com/en-us/102445).

## Use

1. Connect the keyboard by USB and set its selector to **OFF**.
2. Click a key, choose **Assign to**, and select its new action.
3. Click **Save to keyboard** and authorize the administrator prompt.
4. Turn the heart/profile light on to use your saved mappings.

Each save creates a backup and verifies the result. **Undo last save** restores the previous mapping; **Backups** opens the backup folder.

For shortcuts such as **Command+A**, choose **Assign to → Shortcut**, select a modifier and key, then **Use shortcut**. One modifier per shortcut.

Saved macros are read-only.

## Build

With Xcode Command Line Tools and Python 3.12+ installed:

```sh
python3 build.py
```

See [BUILD.md](BUILD.md) for details.

Uses [libusb](third_party/COPYING-libusb) and protocol research from [8bitdo-kbd-mapper](https://github.com/goncalor/8bitdo-kbd-mapper) and [8-retro-kbd-ctl](https://github.com/paulguy/8-retro-kbd-ctl).
