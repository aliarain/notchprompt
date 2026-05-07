import Foundation
import Speech
import AVFoundation
import Combine
import AppKit

// MARK: - DictationManager (Feature 19)

final class DictationManager: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 40)
    @Published var error: String?

    /// Called on main thread with the latest recognized text for the current segment
    var onTextUpdate: ((String) -> Void)?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var configurationChangeObserver: Any?
    private var sessionGeneration: Int = 0

    func start() {
        guard !isRecording else { return }
        cleanup()
        sessionGeneration += 1
        error = nil

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            error = "Microphone access denied. Open System Settings → Privacy & Security → Microphone."
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.requestSpeechAuthAndBegin()
                    } else {
                        self?.error = "Microphone access denied."
                    }
                }
            }
            return
        case .authorized:
            break
        @unknown default:
            break
        }

        requestSpeechAuthAndBegin()
    }

    func stop() {
        isRecording = false
        cleanup()
    }

    private func requestSpeechAuthAndBegin() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.beginRecognition()
                default:
                    self?.error = "Speech recognition not authorized."
                }
            }
        }
    }

    private func cleanup() {
        if let observer = configurationChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationChangeObserver = nil
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func beginRecognition() {
        cleanup()
        audioEngine = AVAudioEngine()

        let locale = UserDefaults.standard.string(forKey: "speech.locale") ?? "en-US"
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognizer not available"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            error = "Audio input unavailable"
            return
        }

        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isRecording else { return }
            self.restartRecognition()
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength { sum += channelData[i] * channelData[i] }
            let rms = sqrt(sum / Float(max(frameLength, 1)))
            let level = CGFloat(min(rms * 5, 1.0))

            DispatchQueue.main.async {
                self?.audioLevels.append(level)
                if (self?.audioLevels.count ?? 0) > 40 { self?.audioLevels.removeFirst() }
            }
        }

        let currentGeneration = sessionGeneration
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    guard self.sessionGeneration == currentGeneration else { return }
                    self.onTextUpdate?(spoken)
                }
            }
            if error != nil {
                DispatchQueue.main.async {
                    guard self.recognitionRequest != nil, self.isRecording else { return }
                    self.restartRecognition()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            self.error = "Audio engine failed: \(error.localizedDescription)"
            isRecording = false
        }
    }

    private func restartRecognition() {
        guard isRecording else { return }
        cleanup()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.isRecording else { return }
            self.beginRecognition()
        }
    }
}
