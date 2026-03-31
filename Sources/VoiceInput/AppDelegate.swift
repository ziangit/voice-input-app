import AppKit
import Speech

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Sub-components

    private let keyMonitor      = KeyMonitor()
    private let speechEngine    = SpeechEngine()
    private let floatingWC      = FloatingWindowController()
    private let textInjector    = TextInjector()
    private let llmRefiner      = LLMRefiner()
    private lazy var settingsWC = SettingsWindowController()

    // MARK: - Menu bar

    private var statusItem: NSStatusItem?
    private var languageMenuItems: [NSMenuItem] = []
    private var llmToggleItem: NSMenuItem?

    // MARK: - State

    private var isRecording = false
    private var permissionsGranted = false

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        buildStatusItem()
        setupKeyMonitor()
        requestPermissions()
    }

    // MARK: - Menu bar

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "VoiceInput")
            button.image?.isTemplate = true
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Language submenu
        let langMenu = NSMenu()
        for lang in Language.allCases {
            let mi = NSMenuItem(title: lang.displayName,
                                action: #selector(selectLanguage(_:)),
                                keyEquivalent: "")
            mi.representedObject = lang.rawValue
            mi.state = (lang == Preferences.shared.language) ? .on : .off
            langMenu.addItem(mi)
            languageMenuItems.append(mi)
        }
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        // LLM submenu
        let llmMenu = NSMenu()
        let toggleItem = NSMenuItem(title: "Enable LLM Refinement",
                                    action: #selector(toggleLLM(_:)),
                                    keyEquivalent: "")
        toggleItem.state = Preferences.shared.llmEnabled ? .on : .off
        llmMenu.addItem(toggleItem)
        llmToggleItem = toggleItem

        llmMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openLLMSettings),
                                      keyEquivalent: "")
        llmMenu.addItem(settingsItem)

        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit VoiceInput",
                                action: #selector(NSApp.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    // MARK: - Menu actions

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let lang = Language(rawValue: rawValue) else { return }

        Preferences.shared.language = lang
        speechEngine.language = rawValue

        for mi in languageMenuItems {
            mi.state = (mi.representedObject as? String == rawValue) ? .on : .off
        }
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        let enabled = !Preferences.shared.llmEnabled
        Preferences.shared.llmEnabled = enabled
        sender.state = enabled ? .on : .off
    }

    @objc private func openLLMSettings() {
        settingsWC.showWindow()
    }

    // MARK: - Key monitor

    private func setupKeyMonitor() {
        keyMonitor.onFnDown = { [weak self] in self?.handleFnDown() }
        keyMonitor.onFnUp   = { [weak self] in self?.handleFnUp()   }
        keyMonitor.start()
    }

    private func handleFnDown() {
        guard !isRecording, permissionsGranted else {
            if !permissionsGranted { requestPermissions() }
            return
        }
        isRecording = true
        floatingWC.show()

        do {
            try speechEngine.startRecording()
        } catch {
            isRecording = false
            floatingWC.hide()
            showAlert("Microphone Error", message: error.localizedDescription)
        }

        speechEngine.onPartialResult = { [weak self] text in
            self?.floatingWC.updateText(text)
        }
        speechEngine.onAudioLevel = { [weak self] level in
            self?.floatingWC.updateLevel(level)
        }
    }

    private func handleFnUp() {
        guard isRecording else { return }
        isRecording = false

        speechEngine.stopRecording { [weak self] rawText in
            guard let self else { return }
            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                self.floatingWC.hide()
                return
            }

            let prefs = Preferences.shared
            if prefs.llmEnabled && prefs.llmConfigured {
                self.floatingWC.showRefining()
                Task { @MainActor in
                    do {
                        let refined = try await self.llmRefiner.refine(text: text)
                        self.injectAndHide(refined)
                    } catch {
                        // Fall back to raw transcription on LLM error
                        self.injectAndHide(text)
                    }
                }
            } else {
                self.injectAndHide(text)
            }
        }
    }

    private func injectAndHide(_ text: String) {
        floatingWC.hide()
        // Small delay so the hide animation doesn't interfere with the paste target
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.textInjector.inject(text: text)
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        speechEngine.requestPermissions { [weak self] granted in
            self?.permissionsGranted = granted
            if !granted {
                self?.showAlert(
                    "Permissions Required",
                    message: "VoiceInput needs microphone and speech recognition access. Please allow in System Settings > Privacy."
                )
            }
        }
    }

    // MARK: - Helpers

    private func showAlert(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText     = title
        alert.informativeText = message
        alert.alertStyle      = .warning
        alert.runModal()
    }
}
