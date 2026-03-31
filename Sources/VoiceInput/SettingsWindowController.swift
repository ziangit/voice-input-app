import AppKit

final class SettingsWindowController: NSWindowController {

    private var baseURLField: NSTextField!
    private var apiKeyField:  NSTextField!   // plain field — fully clearable
    private var modelField:   NSTextField!
    private var statusLabel:  NSTextField!
    private var saveButton:   NSButton!
    private var testButton:   NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LLM Refinement Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
    }

    func showWindow() {
        loadPreferences()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI Construction

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let labelW: CGFloat = 110
        let fieldW: CGFloat = 260
        let rowH:   CGFloat = 22
        let rowGap: CGFloat = 12
        let leftX:  CGFloat = 20
        let fieldX  = leftX + labelW + 8
        var y: CGFloat = contentView.bounds.height - 50

        func addRow(label: String, secure: Bool = false) -> NSTextField {
            let lbl = NSTextField(labelWithString: label)
            lbl.frame = NSRect(x: leftX, y: y, width: labelW, height: rowH)
            lbl.alignment = .right
            contentView.addSubview(lbl)

            let field: NSTextField
            if secure {
                // Use plain NSTextField so the user can fully select/clear;
                // we'll rely on placeholder text to hint it's sensitive.
                let tf = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldW, height: rowH))
                tf.placeholderString = "sk-…"
                tf.usesSingleLineMode = true
                tf.cell?.wraps = false
                tf.cell?.isScrollable = true
                field = tf
            } else {
                field = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldW, height: rowH))
                field.usesSingleLineMode = true
                field.cell?.wraps = false
                field.cell?.isScrollable = true
            }
            contentView.addSubview(field)
            y -= (rowH + rowGap)
            return field
        }

        baseURLField = addRow(label: "API Base URL:")
        baseURLField.placeholderString = "https://api.openai.com/v1"

        apiKeyField = addRow(label: "API Key:", secure: true)

        modelField = addRow(label: "Model:")
        modelField.placeholderString = "gpt-4o-mini"

        y -= 4

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: leftX, y: y, width: 380, height: rowH)
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        y -= (rowH + 14)

        // Buttons
        testButton = NSButton(title: "Test Connection",
                              target: self, action: #selector(testTapped))
        testButton.frame = NSRect(x: leftX, y: y, width: 140, height: 28)
        contentView.addSubview(testButton)

        saveButton = NSButton(title: "Save",
                              target: self, action: #selector(saveTapped))
        saveButton.frame = NSRect(x: fieldX + fieldW - 80, y: y, width: 80, height: 28)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        let prefs = Preferences.shared
        prefs.llmAPIBaseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.llmAPIKey     = apiKeyField.stringValue     // do not trim — key may start/end with chars
        prefs.llmModel      = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        setStatus("Saved.", color: .systemGreen)
    }

    @objc private func testTapped() {
        // Temporarily write fields to prefs for the test
        let prefs = Preferences.shared
        let origBase  = prefs.llmAPIBaseURL
        let origKey   = prefs.llmAPIKey
        let origModel = prefs.llmModel
        prefs.llmAPIBaseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.llmAPIKey     = apiKeyField.stringValue
        prefs.llmModel      = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        setStatus("Testing…", color: .secondaryLabelColor)
        testButton.isEnabled = false

        Task { @MainActor in
            do {
                let result = try await LLMRefiner().test()
                setStatus("OK — got: \"\(result.prefix(40))\"", color: .systemGreen)
            } catch {
                setStatus("Error: \(error.localizedDescription)", color: .systemRed)
                // Restore original prefs on failure
                prefs.llmAPIBaseURL = origBase
                prefs.llmAPIKey     = origKey
                prefs.llmModel      = origModel
            }
            testButton.isEnabled = true
        }
    }

    // MARK: - Helpers

    private func loadPreferences() {
        let p = Preferences.shared
        baseURLField.stringValue = p.llmAPIBaseURL
        apiKeyField.stringValue  = p.llmAPIKey
        modelField.stringValue   = p.llmModel
        statusLabel.stringValue  = ""
    }

    private func setStatus(_ text: String, color: NSColor) {
        statusLabel.stringValue  = text
        statusLabel.textColor    = color
    }
}
