import Cocoa

// =====================================================================
// MARK: - Settings window
// =====================================================================

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    let foldersTable = NSTableView()
    let rulesTable = NSTableView()
    let fallbackCheck = NSButton(checkboxWithTitle: "Sort everything else by file type into a folder named:", target: nil, action: nil)
    let fallbackField = NSTextField()

    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = "Dropsort Settings"
        w.center()
        self.init(window: w)
        buildUI()
    }

    var cfg: Config { Store.shared.config }
    func mutate(_ block: (inout Config) -> Void) {
        var c = Store.shared.config; block(&c); Store.shared.config = c; Store.shared.save()
    }

    func buildUI() {
        guard let content = window?.contentView else { return }
        let pad: CGFloat = 20
        let width: CGFloat = 580 - pad * 2

        func label(_ s: String, _ y: CGFloat, bold: Bool = true) -> NSTextField {
            let t = NSTextField(labelWithString: s)
            t.font = bold ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 11)
            t.frame = NSRect(x: pad, y: y, width: width, height: bold ? 18 : 16)
            content.addSubview(t); return t
        }

        // ---- Watch Folders ----
        _ = label("Watch these folders", 520)
        _ = label("Files dropped into any of these get sorted automatically.", 504, bold: false)
        let fScroll = NSScrollView(frame: NSRect(x: pad, y: 410, width: width, height: 88))
        fScroll.hasVerticalScroller = true; fScroll.borderType = .bezelBorder
        foldersTable.headerView = nil
        let fc = NSTableColumn(identifier: .init("path")); fc.width = width - 4
        foldersTable.addTableColumn(fc)
        foldersTable.dataSource = self; foldersTable.delegate = self
        foldersTable.rowHeight = 22
        fScroll.documentView = foldersTable
        content.addSubview(fScroll)
        let addF = NSButton(title: "＋ Add Folder…", target: self, action: #selector(addFolder))
        addF.bezelStyle = .rounded; addF.frame = NSRect(x: pad, y: 380, width: 130, height: 26)
        content.addSubview(addF)
        let remF = NSButton(title: "－ Remove", target: self, action: #selector(removeFolder))
        remF.bezelStyle = .rounded; remF.frame = NSRect(x: pad + 136, y: 380, width: 100, height: 26)
        content.addSubview(remF)

        // ---- Rules ----
        _ = label("Sorting rules", 344)
        _ = label("Top to bottom: the first rule whose keywords match a filename wins.", 328, bold: false)
        let rScroll = NSScrollView(frame: NSRect(x: pad, y: 150, width: width, height: 170))
        rScroll.hasVerticalScroller = true; rScroll.borderType = .bezelBorder
        for (idn, title, w) in [("name","Name",140.0),("keywords","Keywords",210.0),("dest","Goes to",170.0)] {
            let col = NSTableColumn(identifier: .init(idn)); col.title = title; col.width = w
            rulesTable.addTableColumn(col)
        }
        rulesTable.dataSource = self; rulesTable.delegate = self
        rulesTable.rowHeight = 22
        rulesTable.doubleAction = #selector(editRule)
        rScroll.documentView = rulesTable
        content.addSubview(rScroll)
        let addR = NSButton(title: "＋ Add Rule…", target: self, action: #selector(addRule))
        addR.bezelStyle = .rounded; addR.frame = NSRect(x: pad, y: 120, width: 120, height: 26)
        content.addSubview(addR)
        let editR = NSButton(title: "Edit…", target: self, action: #selector(editRule))
        editR.bezelStyle = .rounded; editR.frame = NSRect(x: pad + 126, y: 120, width: 70, height: 26)
        content.addSubview(editR)
        let remR = NSButton(title: "－ Remove", target: self, action: #selector(removeRule))
        remR.bezelStyle = .rounded; remR.frame = NSRect(x: pad + 202, y: 120, width: 100, height: 26)
        content.addSubview(remR)

        // ---- Fallback ----
        fallbackCheck.target = self; fallbackCheck.action = #selector(toggleFallback)
        fallbackCheck.frame = NSRect(x: pad, y: 74, width: 430, height: 20)
        fallbackCheck.state = cfg.fallbackByType ? .on : .off
        content.addSubview(fallbackCheck)
        fallbackField.frame = NSRect(x: pad + 24, y: 46, width: 200, height: 22)
        fallbackField.stringValue = cfg.fallbackDest
        fallbackField.target = self; fallbackField.action = #selector(fallbackNameChanged)
        fallbackField.placeholderString = "Sorted"
        content.addSubview(fallbackField)

        let hint = label("Tip: keep Dropsort running — it lives in your menu bar (▾ tray icon).", 16, bold: false)
        hint.textColor = .secondaryLabelColor
    }

    // ---- table data ----
    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === foldersTable ? cfg.watchFolders.count : cfg.rules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: "")
        cell.lineBreakMode = .byTruncatingMiddle
        if tableView === foldersTable {
            cell.stringValue = cfg.watchFolders[row]
        } else {
            let r = cfg.rules[row]
            switch tableColumn?.identifier.rawValue {
            case "name": cell.stringValue = r.name
            case "keywords": cell.stringValue = r.keywords.joined(separator: ", ")
            case "dest": cell.stringValue = r.dest + (r.splitByType ? "  ⤷by type" : "")
            default: break
            }
        }
        return cell
    }

    // ---- folder actions ----
    @objc func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = "Watch This Folder"
        if panel.runModal() == .OK, let url = panel.url {
            var p = url.path
            if p.hasPrefix(home.path) { p = "~" + p.dropFirst(home.path.count) }
            mutate { if !$0.watchFolders.contains(p) { $0.watchFolders.append(p) } }
            foldersTable.reloadData()
        }
    }
    @objc func removeFolder() {
        let i = foldersTable.selectedRow; guard i >= 0 else { return }
        mutate { $0.watchFolders.remove(at: i) }
        foldersTable.reloadData()
    }

    // ---- rule actions ----
    @objc func addRule() {
        RuleEditor.present(in: window!, rule: nil) { newRule in
            self.mutate { $0.rules.append(newRule) }
            self.rulesTable.reloadData()
        }
    }
    @objc func editRule() {
        let i = rulesTable.selectedRow; guard i >= 0 else { return }
        RuleEditor.present(in: window!, rule: cfg.rules[i]) { edited in
            self.mutate { $0.rules[i] = edited }
            self.rulesTable.reloadData()
        }
    }
    @objc func removeRule() {
        let i = rulesTable.selectedRow; guard i >= 0 else { return }
        mutate { $0.rules.remove(at: i) }
        rulesTable.reloadData()
    }

    // ---- fallback ----
    @objc func toggleFallback() { mutate { $0.fallbackByType = (fallbackCheck.state == .on) } }
    @objc func fallbackNameChanged() {
        let v = fallbackField.stringValue.isEmpty ? "Sorted" : fallbackField.stringValue
        mutate { $0.fallbackDest = v }
    }
}

// =====================================================================
// MARK: - Rule editor sheet
// =====================================================================

final class RuleEditor: NSObject {
    static func present(in parent: NSWindow, rule: Rule?, completion: @escaping (Rule) -> Void) {
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
                             styleMask: [.titled], backing: .buffered, defer: false)
        let c = sheet.contentView!
        let pad: CGFloat = 20

        func field(_ y: CGFloat, _ ph: String) -> NSTextField {
            let f = NSTextField(frame: NSRect(x: pad, y: y, width: 380, height: 24)); f.placeholderString = ph
            c.addSubview(f); return f
        }
        func cap(_ s: String, _ y: CGFloat) {
            let t = NSTextField(labelWithString: s); t.font = NSFont.systemFont(ofSize: 11)
            t.textColor = .secondaryLabelColor
            t.frame = NSRect(x: pad, y: y, width: 380, height: 14); c.addSubview(t)
        }

        cap("Rule name", 250); let nameF = field(226, "e.g. Invoices")
        cap("Keywords (comma-separated — matched anywhere in the filename)", 200); let kwF = field(176, "invoice, receipt, statement")
        cap("Move into this folder (created inside each watched folder)", 150); let destF = field(126, "Admin/Invoices")
        let splitC = NSButton(checkboxWithTitle: "Split into Video / Audio / Images / Docs subfolders", target: nil, action: nil)
        splitC.frame = NSRect(x: pad, y: 96, width: 380, height: 20); c.addSubview(splitC)
        let appliesPopup = NSPopUpButton(frame: NSRect(x: pad, y: 64, width: 200, height: 26))
        appliesPopup.addItems(withTitles: ["Files & folders", "Files only", "Folders only"])
        c.addSubview(appliesPopup)

        if let r = rule {
            nameF.stringValue = r.name
            kwF.stringValue = r.keywords.joined(separator: ", ")
            destF.stringValue = r.dest
            splitC.state = r.splitByType ? .on : .off
            appliesPopup.selectItem(at: r.appliesTo == "files" ? 1 : r.appliesTo == "folders" ? 2 : 0)
        }

        let okB = NSButton(title: rule == nil ? "Add Rule" : "Save", target: nil, action: nil)
        okB.bezelStyle = .rounded; okB.keyEquivalent = "\r"
        okB.frame = NSRect(x: 300, y: 16, width: 100, height: 30)
        let cancelB = NSButton(title: "Cancel", target: nil, action: nil)
        cancelB.bezelStyle = .rounded; cancelB.keyEquivalent = "\u{1b}"
        cancelB.frame = NSRect(x: 196, y: 16, width: 96, height: 30)
        c.addSubview(okB); c.addSubview(cancelB)

        let handler = SheetHandler(sheet: sheet, parent: parent, nameF: nameF, kwF: kwF, destF: destF,
                                   splitC: splitC, appliesPopup: appliesPopup, completion: completion)
        okB.target = handler; okB.action = #selector(SheetHandler.ok)
        cancelB.target = handler; cancelB.action = #selector(SheetHandler.cancel)
        objc_setAssociatedObject(sheet, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

        parent.beginSheet(sheet, completionHandler: nil)
    }
}

final class SheetHandler: NSObject {
    let sheet: NSWindow, parent: NSWindow
    let nameF, kwF, destF: NSTextField
    let splitC: NSButton, appliesPopup: NSPopUpButton
    let completion: (Rule) -> Void
    init(sheet: NSWindow, parent: NSWindow, nameF: NSTextField, kwF: NSTextField, destF: NSTextField,
         splitC: NSButton, appliesPopup: NSPopUpButton, completion: @escaping (Rule) -> Void) {
        self.sheet = sheet; self.parent = parent; self.nameF = nameF; self.kwF = kwF; self.destF = destF
        self.splitC = splitC; self.appliesPopup = appliesPopup; self.completion = completion
    }
    @objc func ok() {
        let name = nameF.stringValue.trimmingCharacters(in: .whitespaces)
        let dest = destF.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !dest.isEmpty else { NSSound.beep(); return }
        let kws = kwF.stringValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let applies = ["both","files","folders"][appliesPopup.indexOfSelectedItem]
        completion(Rule(name: name, keywords: kws, dest: dest, splitByType: splitC.state == .on, appliesTo: applies))
        parent.endSheet(sheet); sheet.orderOut(nil)
    }
    @objc func cancel() { parent.endSheet(sheet); sheet.orderOut(nil) }
}
