# Shortcut mappings

The Assign to picker now has a Shortcut category. Choose one modifier and one ordinary key, review the combination, then use it as a draft. Save, backup, verification and Undo use the existing single-key writer.

The mapping for Command+A is `07 e3 04`, followed by 21 zero bytes. The modifier byte is a usage (`e0`–`e7`), not a bitmask. Both left and right variants of Command, Shift, Option and Control are available. Letter and number searches match the literal key. Function keys up to F24 are supported.

No verified normal-mapping encoding was found for multiple modifiers. Command+Shift+A would need the macro path. General macro mutation remains blocked because individual replacement has failed readback on this keyboard.

## Protocol evidence

- [8-retro-kbd-ctl](https://github.com/paulguy/8-retro-kbd-ctl/blob/main/src/eightkbdctl/lib/eightkbd.py) represents a key mapping as one modifier usage plus one key usage.
- [8db-retro-config](https://github.com/Aryaman73/8db-retro-config#map-a-key-to-a-modifier--key-chord--eg-super-a--f13) documents the same `07 <modifier-usage> <key-usage>` format and single-modifier chords.
- Offline inspection of official Windows V2 v1.35: legacy `_SetMapping` writes type 7 and four destination bytes. `KeyBoardTools.getuint` fills the final two bytes with zero for keyboard destinations, including its built-in Shift+F10 combination. Nonzero values in the last byte were confined to mouse actions. `_SetShortCut` writes type 12 consumer/media usages; its name does not indicate arbitrary key combinations.

The app does not write speculative modifier masks, additional modifier usages or unknown trailing bytes.

## Validation — 2026-10-06

Automated checks cover all eight modifier usages, invalid combinations, search, explicit confirmation, Cancel, empty results, reopening an existing shortcut, draft retention and full-profile verification for save and Undo. The build passes and the app signature verifies.

The actual native app was used to assign Pause to Command+A. Its writer acknowledged and read back the requested 24 bytes. Independent comparison of the full before/after snapshots confirmed that only Pause changed; the other 12 mapping records and all macro definitions were preserved.

Physical playback, modifier release, power-cycle persistence and hardware Undo are still awaiting verification. Screenshots: [picker](10-shortcut-picker.png), [saved mapping](11-shortcut-saved.png).
