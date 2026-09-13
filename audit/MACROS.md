# Macro implementation and verification

The sequence editor is implemented in the established native style. It loads existing readable definitions, offers names and repeats, inserts balanced shortcuts, supports searching keys, and edits/removes/reorders press, release and pause events. Native UI checks confirmed these interactions. Save, removal and one-level Undo code use a dedicated direct-interrupt USB helper with before/after snapshots and full collateral verification.

## Hardware blocker

The two attempted Scroll Lock macro-name writes returned `54 e4 07`. Neither attempt reached sequence transmission or ordinary mapping writes. The first snapshot after the first rejection exactly matched the pre-test baseline. After the second rejection (using the reference space encoding), macro metadata changed and the screenshot macro became unreadable. The cause is not established. The pre-existing invalid 0x74/0x75 macro entries are not safe to erase speculatively.

The current app and helper reject macro mutation whenever the complete macro table cannot be validated and backed up. A unit and command-level check confirms the historical request now exits before USB access or administrator authorization. All automated checks and signature checks pass. This is not a successful onboard macro implementation yet: creation, editing, removal, Undo and playback remain unverified on hardware.

The user physically reconnected the keyboard. `work/8bitdo/macro-after-reconnect-full.json` confirms all 41 mapping records and the profile name still match `work/8bitdo/macro-implementation-before.json`. Macro damage persisted: screenshot (0x46) is unreadable and the incomplete Scroll Lock (0x47) entry remains. Recovery has not succeeded. No further hardware writes were performed. Historical diagnostics must not be rerun to bypass the new guard.


## Official Windows software inspection

Inspected, without executing, the vendor V1.35 Windows distribution from https://support.8bitdo.com/bd-uploads/files/ultimate_soft/8BitDo_Ultimate_Software_V2_Windows_V1.35.zip. The extracted files and disassembly are under `work/8bitdo/macro-research/`.

- Native lowercase `writeMacroName` and `writeMacroJP` use the legacy 0x74/0x76 packets. The short name payload agrees with the corrected reference encoding. This does not establish compatibility with the current 85HA firmware or explain the rejected write.
- Managed `JPMacroView.writeMacro` (method 2078) waits 100 ms around operations and closes/reopens HID after disabling raw reports. Our implementation has different timing. This is an unproven possible difference, not a diagnosis or reason to retry against damaged storage.
- Native `ClearMacro` uses its caller's second argument in the fourth report byte. Managed replacement passes the saved `MacroDatas.Count`. Removed our hardcoded 0x8c and added a packet builder using the validated saved event count, with offline golden screenshot and upper-bound tests. No deletion command has been tested on hardware.
- Managed `ClearAllMacro` (method 2039) loops over individual entries and calls `ClearMacro`; it is not a separate macro-store erase primitive. It depends on existing metadata and supplies no verified corruption recovery route.
- Native `ClearProfile` uses another command family. Its export name alone provides no basis for using it on this keyboard. No reset command was sent.
- Replacing an existing macro in the official legacy UI also deletes the old definition first. Our replacement implementation still differs. Keep mutation blocked; do not treat the packet-builder correction as a complete protocol fix.

## Recovery boundary

The full pre-test snapshot and the exact original screenshot bytes are available. The pre-existing unreadable 0x74/0x75 entries were never recoverable exports. No proven command sequence currently restores the screenshot while preserving those entries. A reset or deletion of unknown entries could permanently lose settings and has not been authorized or attempted. Obtain a firmware-compatible recovery method before further mutation. The current app remains usable for ordinary keys that do not carry macro entries.

## September 13 recovery investigation

A fresh read (`work/8bitdo/macro-retry-sep13-before.json`) exactly matches the previous post-reconnect snapshot. No persistent writes were performed. The official Windows keyboard profile deletion path was identified: managed `JPPlatFormView.deleteMacro` calls `writeName` with length zero for PID_JP/PID_108JP; native `writeName` constructs `52 70` padded to 33 bytes. This is distinct from the unrelated native `ClearProfile` export.

An exact reset-and-mapping-restoration plan, fresh snapshot, and original screenshot definition are prepared under `work/8bitdo/recovery-sep13/`. It would restore all 12 recognized mapping records (eight original custom mappings plus four explicit defaults), discard 29 other stored mapping entries, and erase all four macro entries. Unknown entries cannot be guaranteed recoverable. Explicit user approval is required before executing this destructive recovery. Screenshot re-creation would be a separate attempt after verified normal-mapping restoration. Hardware recovery remains unverified; app macro guards remain active.


## Approved recovery executed September 13

The user explicitly approved resetting and rebuilding the profile. `work/8bitdo/recovery-sep13/reset-attempt.log` shows the reset acknowledgement, empty profile/mapping/macro reads, profile recreation, and all twelve mapping acknowledgements and readbacks. `after-rebuild.json` independently confirms exactly the intended 12 records and an empty macro list after returning USB control to macOS.

The scoped screenshot restoration used the exact original name and event bytes, with 150 ms waits after disabling raw reports and after the name acknowledgement. Both name and sequence were acknowledged. `after-screenshot.json` independently matches the entire original screenshot definition and all 12 rebuilt mapping records; only key 0x46 remains in the macro list. No extra/unreadable entries remain. Physical reconnect and playback verification are pending. This supersedes the earlier unrecovered status without removing the incident evidence.

The app helper now waits between operations and deletes a validated existing definition before replacement, as the official legacy UI does, checking that other list entries remain unchanged. General create/edit/remove/Undo tests are still pending; the successful screenshot restore is not evidence those paths all work.


## Screenshot correction and replacement failure

The user power-cycled the keyboard, confirmed normal key behavior, and reported Print Screen typed `›`. The original backed-up sequence was Option-Shift-4. A replacement changed only the two Option modifier event bytes to Command (0xe2 → 0xe3). The updated helper deleted the saved macro using its event count, verified the list empty, then recreated its name and sequence; every command returned 54e408. Nevertheless the sequence read returned 54e40a, and the independent snapshot showed an empty macro list. All 12 normal mappings remained unchanged. See `work/8bitdo/recovery-sep13/screenshot-correction.log` and `after-correction-attempt.json`.

The approved reset/rebuild recovery was then repeated against the known 12-record profile, with no unknown entries to discard. The corrected Command-Shift-4 macro was created on the clean profile and all bytes independently verified. Final evidence: `work/8bitdo/recovery-corrected-screenshot/after-screenshot.json`. Corrected physical playback is pending.

All macro mutations are now disabled unconditionally in the app and helper, including for valid tables. The scoped historical recovery helpers are not bundled in the app and must not be rerun against a changed state. This is successful profile recovery and initial macro creation, not a verified general macro editor. An acknowledgement is demonstrably insufficient evidence for replacement.

The user subsequently confirmed that the corrected Print Screen key starts screenshot selection. Recovery is complete; general macro editor functionality remains paused.
