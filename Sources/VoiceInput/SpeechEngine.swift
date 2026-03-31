import AVFoundation
import Speech

final class SpeechEngine: NSObject {

    // Callbacks (always called on main thread)
    var onPartialResult: ((String) -> Void)?
    var onAudioLevel:    ((Float) -> Void)?

    var language: String = Preferences.shared.language.rawValue

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine  = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?

    private var lastTranscription = ""
    private var stopCompletion: ((String) -> Void)?
    private var timeoutItem: DispatchWorkItem?
    private var isRunning = false

    // MARK: - Public API

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    func startRecording() throws {
        guard !isRunning else { return }

        recognizer = SFSpeechRecognizer(locale: Locale(identifier: language))
        recognizer?.defaultTaskHint = .dictation

        lastTranscription = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.processAudioLevel(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.lastTranscription = text
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if result.isFinal {
                        self.deliverFinalResult(text)
                    } else {
                        self.onPartialResult?(text)
                    }
                }
            } else if error != nil {
                DispatchQueue.main.async { [weak self] in
                    self?.deliverFinalResult(self?.lastTranscription ?? "")
                }
            }
        }
    }

    func stopRecording(completion: @escaping (String) -> Void) {
        guard isRunning else {
            completion(lastTranscription)
            return
        }
        stopCompletion = completion

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRunning = false

        // Safety timeout — speech recognizer should deliver final within ~5s
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let cb = self.stopCompletion {
                self.stopCompletion = nil
                cb(self.lastTranscription)
            }
        }
        timeoutItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    // MARK: - Private

    private func deliverFinalResult(_ text: String) {
        timeoutItem?.cancel()
        timeoutItem = nil
        guard let cb = stopCompletion else { return }
        stopCompletion = nil
        cb(text)
    }

    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        var sumSquares: Float = 0
        for i in 0..<count { sumSquares += data[i] * data[i] }
        let rms = (sumSquares / Float(count)).squareRoot()
        // Scale so typical speech (~0.05–0.15 rms) maps nicely to 0.4–1.0
        let normalized = min(rms * 8.0, 1.0)

        DispatchQueue.main.async { [weak self] in
            self?.onAudioLevel?(normalized)
        }
    }
}
