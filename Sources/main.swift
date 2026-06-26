import Cocoa
import UniformTypeIdentifiers

// =====================================================================
// MARK: - Model
// =====================================================================

struct Rule: Codable {
    var name: String
    var keywords: [String]
    var dest: String          // subfolder relative to each watch folder
    var splitByType: Bool     // route into dest/<Video|Audio|Images|Docs|Other>
    var appliesTo: String     // "both" | "files" | "folders"

    init(name: String, keywords: [String], dest: String, splitByType: Bool = false, appliesTo: String = "both") {
        self.name = name; self.keywords = keywords; self.dest = dest
        self.splitByType = splitByType; self.appliesTo = appliesTo
    }
}

struct Config: Codable {
    var watchFolders: [String]
    var rules: [Rule]
    var fallbackByType: Bool
    var fallbackDest: String
    var paused: Bool

    static var defaultConfig: Config {
        Config(
            watchFolders: ["~/Downloads", "~/Desktop"],
            rules: [
                Rule(name: "Screenshots", keywords: ["screenshot", "screen shot", "cleanshot"], dest: "Screenshots", appliesTo: "files"),
                Rule(name: "Screen Recordings", keywords: ["screen recording"], dest: "Screen Recordings", appliesTo: "files"),
                Rule(name: "Installers", keywords: [".app", ".dmg", ".pkg"], dest: "Installers"),
            ],
            fallbackByType: true,
            fallbackDest: "Sorted",
            paused: false
        )
    }
}

// =====================================================================
// MARK: - Paths & store
// =====================================================================

let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser
let configDir  = home.appendingPathComponent(".config/dropsort")
let configURL  = configDir.appendingPathComponent("config.json")
let logURL     = home.appendingPathComponent("Library/Logs/Dropsort.log")

func expand(_ p: String) -> String { (p as NSString).expandingTildeInPath }

final class Store {
    static let shared = Store()
    var config: Config = .defaultConfig

    func load() {
        if let data = try? Data(contentsOf: configURL),
           let c = try? JSONDecoder().decode(Config.self, from: data) {
            config = c
        } else {
            config = .defaultConfig
            save()
        }
    }
    func save() {
        try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(config) { try? data.write(to: configURL) }
        NotificationCenter.default.post(name: .configChanged, object: nil)
    }
}

extension Notification.Name { static let configChanged = Notification.Name("dropsort.configChanged") }

// =====================================================================
// MARK: - Type maps (built-in)
// =====================================================================

func typeOfExt(_ ext: String) -> String {
    switch ext {
    case "mp4","mov","m4v","avi","mkv","webm","3gp": return "Video"
    case "mp3","wav","m4a","aiff","aif","flac","opus","aac": return "Audio"
    case "png","jpg","jpeg","webp","avif","gif","heic","svg","tiff","psd","bmp": return "Image"
    case "pdf": return "PDF"
    case "doc","docx","txt","md","csv","xlsx","xls","pptx","ppt","key","pages","rtf","numbers": return "Document"
    case "zip","rar","7z","tar","gz","tgz": return "Archive"
    case "otf","ttf","woff","woff2": return "Font"
    case "dmg","pkg": return "Installer"
    default: return "Other"
    }
}
// catch-all folder name per type
func fallbackFolder(_ ext: String) -> String {
    switch typeOfExt(ext) {
    case "Video": return "Videos"
    case "Audio": return "Audio"
    case "Image": return "Images"
    case "PDF": return "PDFs"
    case "Document": return "Documents"
    case "Archive": return "Archives"
    case "Font": return "Fonts"
    case "Installer": return "Installers"
    default: return "Other"
    }
}
// per-rule split subfolder
func splitFolder(_ ext: String) -> String {
    switch typeOfExt(ext) {
    case "Video": return "Video"
    case "Audio": return "Audio"
    case "Image": return "Images"
    case "PDF","Document": return "Docs"
    default: return "Other"
    }
}

let busyExts: Set<String> = ["crdownload","download","part","partial","opdownload","tmp","filepart","crswap","aria2"]

// =====================================================================
// MARK: - Engine
// =====================================================================

func logLine(_ s: String) {
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let line = "\(df.string(from: Date()))  \(s)\n"
    guard let data = line.data(using: .utf8) else { return }
    try? fm.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let fh = try? FileHandle(forWritingTo: logURL) {
        fh.seekToEndOfFile(); fh.write(data); try? fh.close()
    } else { try? data.write(to: logURL) }
}

func isFileOpen(_ url: URL) -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    p.arguments = ["--", url.path]
    p.standardOutput = Pipe(); p.standardError = Pipe()
    do { try p.run(); p.waitUntilExit() } catch { return false }
    return p.terminationStatus == 0
}

func ruleMatches(_ lname: String, _ rule: Rule, isDir: Bool) -> Bool {
    switch rule.appliesTo {
    case "files": if isDir { return false }
    case "folders": if !isDir { return false }
    default: break
    }
    for k in rule.keywords {
        let kl = k.lowercased()
        if kl.isEmpty { continue }
        if lname.contains(kl) { return true }
    }
    return false
}

func safeMove(_ src: URL, toDir destDir: URL) {
    if src.standardizedFileURL == destDir.standardizedFileURL { return }
    try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
    let base = src.lastPathComponent
    var target = destDir.appendingPathComponent(base)
    if fm.fileExists(atPath: target.path) {
        let ns = base as NSString
        let stem = ns.deletingPathExtension, ext = ns.pathExtension
        var n = 1
        repeat {
            let nm = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            target = destDir.appendingPathComponent(nm); n += 1
        } while fm.fileExists(atPath: target.path)
    }
    do {
        try fm.moveItem(at: src, to: target)
        logLine("MOVED  \(base)  ->  \(destDir.path.replacingOccurrences(of: home.path + "/", with: "~/"))")
    } catch {
        logLine("ERR    \(base)  (\(error.localizedDescription))")
    }
}

let sweepQueue = DispatchQueue(label: "dropsort.sweep")
var sweeping = false

// folders the app itself creates as destinations — never re-sort these
func destinationNames(_ cfg: Config) -> Set<String> {
    var s = Set<String>()
    for r in cfg.rules { s.insert((r.dest as NSString).pathComponents.first ?? r.dest) }
    s.insert((cfg.fallbackDest as NSString).pathComponents.first ?? cfg.fallbackDest)
    return s
}

func sweep(reason: String) {
    sweepQueue.async {
        if sweeping { return }
        sweeping = true; defer { sweeping = false }
        Store.shared.load()
        let cfg = Store.shared.config
        if cfg.paused { return }
        let protectedNames = destinationNames(cfg)
        var moved = 0

        for wf in cfg.watchFolders {
            let watch = URL(fileURLWithPath: expand(wf))
            guard let entries = try? fm.contentsOfDirectory(
                at: watch,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: []) else {
                logLine("RUN (\(reason))  cannot read \(wf) — grant access when macOS prompts")
                continue
            }
            for url in entries where !url.lastPathComponent.hasPrefix(".") {
                let name = url.lastPathComponent
                if name == "Icon\r" { continue }
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let l = name.lowercased()
                let ext = (name as NSString).pathExtension.lowercased()

                if isDir {
                    if protectedNames.contains(name) { continue }
                    if let mt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       Date().timeIntervalSince(mt) < 60 { continue }   // let unzips settle
                } else {
                    if busyExts.contains(ext) { continue }
                    if isFileOpen(url) { continue }
                }

                var placed = false
                for rule in cfg.rules where ruleMatches(l, rule, isDir: isDir) {
                    var dest = watch.appendingPathComponent(rule.dest)
                    if rule.splitByType && !isDir { dest = dest.appendingPathComponent(splitFolder(ext)) }
                    safeMove(url, toDir: dest); moved += 1; placed = true; break
                }
                if placed { continue }

                if !isDir && cfg.fallbackByType {
                    safeMove(url, toDir: watch.appendingPathComponent(cfg.fallbackDest).appendingPathComponent(fallbackFolder(ext)))
                    moved += 1
                }
            }
        }
        if moved > 0 { logLine("RUN (\(reason))  sorted \(moved) item(s)") }
    }
}

// =====================================================================
// MARK: - App
// =====================================================================

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var toggleItem: NSMenuItem!
    var statusLine: NSMenuItem!
    var sources: [DispatchSourceFileSystemObject] = []
    var debounce: DispatchWorkItem?
    var timer: Timer?
    var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ n: Notification) {
        Store.shared.load()
        buildMenu()
        rebuildWatchers()
        timer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { _ in sweep(reason: "timer") }
        NotificationCenter.default.addObserver(self, selector: #selector(onConfigChanged), name: .configChanged, object: nil)
        sweep(reason: "launch")
        checkAccessAndPrompt()
    }

    @objc func onConfigChanged() { rebuildWatchers(); refresh() }

    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu(); menu.delegate = self
        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: ""); statusLine.isEnabled = false
        menu.addItem(statusLine); menu.addItem(.separator())
        toggleItem = mk("", #selector(togglePause)); menu.addItem(toggleItem)
        menu.addItem(mk("Sort Now", #selector(sortNow)))
        menu.addItem(.separator())
        menu.addItem(mk("Settings…", #selector(openSettings), ","))
        menu.addItem(mk("View Log", #selector(openLog)))
        menu.addItem(.separator())
        menu.addItem(mk("Grant Full Disk Access…", #selector(grantFDA)))
        menu.addItem(.separator())
        menu.addItem(mk("Quit Dropsort", #selector(quit), "q"))
        statusItem.menu = menu
        refresh()
    }

    @objc func grantFDA() {
        NSWorkspace.shared.selectFile(Bundle.main.bundlePath, inFileViewerRootedAtPath: "")
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFilesAccess") {
            NSWorkspace.shared.open(u)
        }
    }

    func checkAccessAndPrompt() {
        let blocked = Store.shared.config.watchFolders.contains { wf in
            (try? fm.contentsOfDirectory(atPath: expand(wf))) == nil
        }
        guard blocked else { return }
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "Dropsort needs permission to sort your files"
            a.informativeText = "Give Dropsort Full Disk Access so it can move files in the folders you watch:\n\n1. Click “Open Settings”.\n2. Turn on Dropsort in the list (drag it in with ＋ if it isn’t there).\n\nDropsort only ever moves files between folders you choose — nothing leaves your Mac."
            a.addButton(withTitle: "Open Settings")
            a.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if a.runModal() == .alertFirstButtonReturn { self.grantFDA() }
        }
    }
    func mk(_ t: String, _ s: Selector, _ k: String = "") -> NSMenuItem {
        let mi = NSMenuItem(title: t, action: s, keyEquivalent: k); mi.target = self; return mi
    }
    func menuWillOpen(_ m: NSMenu) { refresh() }

    func refresh() {
        let on = !Store.shared.config.paused
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: on ? "tray.and.arrow.down.fill" : "pause.circle",
                              accessibilityDescription: "Dropsort")
            b.image?.isTemplate = true
        }
        statusLine?.title = on ? "Dropsort: ON" : "Dropsort: PAUSED"
        toggleItem?.title = on ? "Pause Sorting" : "Resume Sorting"
    }

    func rebuildWatchers() {
        for s in sources { s.cancel() }
        sources.removeAll()
        for wf in Store.shared.config.watchFolders {
            let path = expand(wf)
            let fd = open(path, O_EVTONLY)
            if fd < 0 { continue }
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .rename, .delete], queue: .main)
            src.setEventHandler { [weak self] in self?.scheduleSweep() }
            src.setCancelHandler { close(fd) }
            src.resume()
            sources.append(src)
        }
    }

    func scheduleSweep() {
        debounce?.cancel()
        let w = DispatchWorkItem { sweep(reason: "watch") }
        debounce = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: w)
    }

    @objc func togglePause() { Store.shared.config.paused.toggle(); Store.shared.save(); refresh(); if !Store.shared.config.paused { sweep(reason: "resume") } }
    @objc func sortNow() { sweep(reason: "manual") }
    @objc func openLog() { NSWorkspace.shared.open(logURL) }
    @objc func openSettings() {
        if settings == nil { settings = SettingsWindowController() }
        settings?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settings?.window?.makeKeyAndOrderFront(nil)
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
