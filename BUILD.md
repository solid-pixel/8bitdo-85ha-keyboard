# Build

Requirements: Apple Silicon Mac, Xcode Command Line Tools, and Python 3.12 or later for a clean libusb build.

Run `python3 build.py` from the repository root. Use `python3 build.py --replace` to replace a build with this app's bundle identifier. Quit the editor before rebuilding. The previous build is retained under `.build/previous.app`.

The builder compiles the AppKit app, both USB helpers, and the automated tests. It runs the tests, assembles `85HA Keyboard.app`, and verifies its local code signature. It builds the bundled libusb source archive into `.build/libusb-build` on the first run and reuses that local library afterward. A fresh checkout needs no files from the original development workspace and no network downloads. No files in `/Applications` are modified.

`--85ha-demo` is an application argument for a preview using the bundled snapshot. Saving is disabled in that mode.

The source and bundled libusb archive provide the material needed to rebuild or relink the writer. No persistent privileged helper or launch service is installed; each save uses macOS administrator authorization for one bounded USB operation.
