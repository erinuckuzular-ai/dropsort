# Dropsort

**Keep your Downloads and Desktop tidy, automatically.** Dropsort is a tiny macOS menu-bar app that watches the folders you choose and files things into folders the moment they appear — based on rules you set up with a few clicks. No coding.

![menu bar](https://img.shields.io/badge/macOS-12%2B-black) ![license](https://img.shields.io/badge/license-MIT-blue)

---

## What it does

- 🗂 **Auto-sorts** new files in **Downloads, Desktop, or any folder you add**
- 🏷 **Your rules:** "anything with *invoice* → Admin/Invoices", "*punchin* → Shows/Punchin", etc.
- 🧲 **Sort by type** as a fallback — videos, audio, images, PDFs, archives each get a folder
- ⏸ **Pause/Resume** any time from the menu bar
- 🔒 **Private:** files only move *between folders on your Mac*. Nothing is uploaded.

## Install

1. Download **`Dropsort.dmg`** from the [latest release](../../releases/latest).
2. Open it and drag **Dropsort** into **Applications**.
3. **First launch:** right-click Dropsort → **Open** → **Open** (needed once because the app isn't notarized — see note below).
4. When asked, click **Open Settings** and switch **Dropsort ON** under **Full Disk Access**. This lets it move files in the folders you pick. (You can also do this anytime via the menu-bar icon → *Grant Full Disk Access…*)

That's it — Dropsort lives in your menu bar (tray icon ▾) and starts at login.

> **Gatekeeper note:** Dropsort is open-source and *ad-hoc signed*, not Apple-notarized (notarization needs a paid Apple Developer account). That's why the first open needs a right-click. If you'd rather not, [build it yourself](#build-from-source) in one command.

## Customise it (no code)

Click the menu-bar icon → **Settings…**

- **Watch these folders** — add Downloads, Desktop, or any folder with **＋ Add Folder…**
- **Sorting rules** — **＋ Add Rule…**, give it a name, some keywords (matched anywhere in the filename), and the folder it should go to. Optionally split into Video/Audio/Images/Docs subfolders. Rules are checked top-to-bottom; first match wins.
- **Sort everything else by type** — leftover files get filed into `Sorted/Videos`, `Sorted/Audio`, etc.

Changes apply immediately.

## Build from source

Requires Xcode command-line tools (`xcode-select --install`).

```sh
git clone https://github.com/erinuckuzular-ai/dropsort.git
cd dropsort
./build.sh        # compiles, installs to ~/Applications, sets up login agent
```

## How it works

A single compiled Swift menu-bar app (~AppKit, no dependencies). It watches each folder with `DispatchSource` file-system events (1.5s debounce) plus a 3-minute safety sweep, skips in-progress downloads, never overwrites (auto-suffixes duplicates), and reads its rules from `~/.config/dropsort/config.json` (edited for you by the Settings window).

## License

MIT — see [LICENSE](LICENSE).
