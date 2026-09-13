# 85HA Keyboard

A standalone Apple Silicon Mac app for normal-key mappings saved on the 8BitDo 85HA keyboard, with an experimental macro sequence editor. It does not require Ultimate Software V2.

## Build

See [BUILD.md](BUILD.md). On an Apple Silicon Mac with Xcode Command Line Tools and Python 3.12 or later:

```sh
python3 build.py
```

The app is built in the repository root. Build products are ignored by Git.

## Macro implementation status

The sequence editor includes names, repeats, searchable keys, shortcut insertion, press/release/pause steps, reordering, and removal. **All macro saves, removals, and Undo are paused in the app and helper**: individual replacement proved unreliable even on a readable profile. Saved sequences can be inspected.

On September 13, the user approved erasing and rebuilding the damaged `work` profile. The reset was acknowledged and all three lists were verified empty. All 12 recognized mapping records (eight custom mappings and four modifier defaults) were restored and independently read back. The 29 extra mapping entries and four old macro entries were cleared as approved.

The original screenshot macro was then restored successfully: its name and every sequence byte match the original backup, and every normal mapping remained unchanged. After a physical reconnect, the user confirmed normal keys work. The original macro used Option-Shift-4 and typed a character instead of opening screenshot selection. It was corrected to Command-Shift-4 through another approved profile rebuild; the corrected bytes and all normal mappings were independently verified. The user confirmed the corrected Print Screen key opens screenshot selection. The earlier failures remain documented in `audit/MACROS.md`; a clean profile accepted the command, but the precise failure cause is not proven.

Following the official delete-before-recreate sequence did not solve replacement: every operation was acknowledged, but a separate read showed the macro missing. The app now blocks all macro mutations before USB access, including on valid profiles. Only the separately authorized full-profile rebuild and initial macro creation succeeded. No firmware changes were made.

## Earlier normal-mapping validation

On 2026-09-12, the actual app UI was used to save Scroll Lock → F13 and then undo it. Both operations were acknowledged and read back after the USB driver was reconnected. Only Scroll Lock changed during the test; undo restored the entire starting mapping snapshot and the macro list exactly. A physical power cycle was not part of this test.

The interface now uses a clickable physical keyboard layout with saved mappings on the key faces. It was checked for click selection, filtered selection, empty searches, macro keys remaining read-only, and the third bottom-left key showing Command. Unsaved destinations now remain attached to their keys when switching selection or reloading; Discard this change clears the selected draft. Closing warns before discarding unsaved choices. No hardware writes were performed for this visual update. The mapping chooser has its own search, categories, empty-result message, and Cancel action. Connection guidance and preserved-entry diagnostics are available under Connection & help. A stale-selection bug found during earlier testing was fixed before the live save test. Automated checks cover draft retention across key switches and searches, mapping search and categories, macro protection, selection resolution, command validation, input bounds, default mapping normalization, unexpected changes elsewhere in the profile, and shell argument quoting. See `VALIDATION.json` for the separate hashes and results of the earlier save test and current interface checks.

## Use

1. Connect the keyboard by USB and set its selector to OFF.
2. Open **85HA Keyboard.app**. The app reads its saved mappings automatically.
3. Click a physical key on the keyboard diagram, or search by key or saved mapping name. Search dims keys that do not match.
4. Click the **Assign to** control, search or filter by Keys / Modifiers / Media, and select a destination. Review the old → new summary, then click **Save to keyboard**.
5. Authorize the USB operation in the macOS administrator prompt. The keyboard may pause briefly while saving.
6. Wait for the verified save message. Enable the heart/profile light to use your onboard mappings.

Key faces display saved mappings; small secondary labels identify remapped keys, and an orange outline marks an unsaved choice. Hover for the full mapping name. Special A/B buttons are shown for orientation but cannot be edited. The second and third bottom-left keys are labeled by position as well as their original legends. **Undo last save** restores the preceding mapping while the app remains open; reloading clears that undo action.

## Scope

- Supports the wired 85HA, USB ID `2dc8:5200`, on this Apple Silicon Mac.
- Edits one normal physical key per save. Destinations include normal keys, F13–F24, modifiers, selected media controls, and disabled.
- Click **Create macro…** or **Edit macro…** to open the sequence editor. The rebuilt profile has a readable macro table; macro saves/removal/Undo are paused. Firmware updates, resets, and profile deletion are not implemented.
- Editable macros are limited to 128 steps, 1–100 repeats, pauses up to 10 seconds, and a conservative 60-second playback budget. Every press must have a release. Macro names use the device’s 28-byte name field. Media actions and recording physical typing are not implemented.
- Existing extra or unrecognized profile entries are preserved and checked for unexpected changes after each save. This app does not repair or erase them.
- Uses native HID for profile reads and direct USB interrupt transfers for mapping writes. Native HID mapping writes are absent from the app's reader.
- Saves require macOS administrator authorization. The app does not request Accessibility or Input Monitoring permission.

## Backups and verification

Each save first writes a mapping snapshot and requested change to:

`~/Library/Application Support/8BitDo 85HA Editor/Backups/`

The folder also holds the USB log and verified resulting snapshot. Use **Backups** to open it. New backups include mappings, the macro list, and complete definitions for readable physical macro keys. Unreadable entries are explicitly marked; they are not a recoverable export of those entries.

The app refuses a save if the keyboard changed since it was loaded, if a normal mapping targets a macro key, if a macro save cannot back up every existing macro, or if the request is unsupported. It verifies the target, reopens the keyboard after the USB driver is restored, and checks the rest of the mapping snapshot and macro list. An unconfirmed save is not retried automatically; reload before continuing.

## Source

`src/Editor.m` is the AppKit UI; `src/Device.m` is the read-only HID client; `src/Writer.c` is the narrowly scoped USB writer. `src/MacroEditor.inc` contains the sequence editor and save flow; `src/MacroWriter.c` contains the direct-USB macro writer. `src/Macro.h` and `src/MacroModel.h` validate and decode macro data. `src/Mapping.h` holds mapping validation and normalization rules. `src/Tests.m` exercises the safeguards.

The app is locally signed for this machine and is not notarized. It is an experimental local tool, not an official 8BitDo product.

libusb 1.0.29 is statically linked into the writer under LGPL 2.1 or later. Its license and source archive are included in `third_party/`. Protocol references used during investigation: [goncalor/8bitdo-kbd-mapper](https://github.com/goncalor/8bitdo-kbd-mapper) and [paulguy/8-retro-kbd-ctl](https://github.com/paulguy/8-retro-kbd-ctl).

The main canvas uses a very light gray background in light appearance, with white key faces and editor panel. The heart-light reminder appears beside the status in the footer.

## Development records

The audit documents and `VALIDATION.json` retain the investigation history. References to `work/8bitdo/` or `../../work/` identify evidence in the original local workspace, not files required to build the app. Raw device backups, recovery executables, downloaded vendor software, and modified copies of Ultimate Software are not distributed in this repository. The demo profile is a historical test fixture, not a profile to restore to hardware.
