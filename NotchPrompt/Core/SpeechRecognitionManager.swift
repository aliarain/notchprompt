import Foundation
import Speech
import AVFoundation
import Combine

final class SpeechRecognitionManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var lastSpokenWords: String = ""
    @Published var wordsPerMinute: Double = 0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var wordTimestamps: [(word: String, time: Date)] = []
    var onSpeechDetected: ((Double) -> Void)?

    init() {
        // Don't request authorization on init - wait until user activates voice mode
    }

    func requestAuthorization(completion: (() -> Void)? = nil) {
        guard authorizationStatus == .notDetermined else {
            completion?()
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                completion?()
            }
        }
    }

    func startListening() {
        // Request authorization first if needed
        if authorizationStatus == .notDetermined {
            requestAuthorization { [weak self] in
                self?.startListening()
            }
            return
        }

        guard authorizationStatus == .authorized,
              let recognizer = speechRecognizer,
              recognizer.isAvailable else {
            return
        }

        stopListening()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isListening = true
        } catch {
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let words = text.split(separator: " ")

                if let lastWord = words.last {
                    let now = Date()
                    self.wordTimestamps.append((String(lastWord), now))

                    self.wordTimestamps = self.wordTimestamps.filter {
                        now.timeIntervalSince($0.time) < 10
                    }

                    if self.wordTimestamps.count >= 2 {
                        let duration = now.timeIntervalSince(self.wordTimestamps.first!.time)
                        if duration > 0 {
                            let wpm = Double(self.wordTimestamps.count) / duration * 60
                            DispatchQueue.main.async {
                                self.wordsPerMinute = wpm
                                self.onSpeechDetected?(wpm)
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.lastSpokenWords = text
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        wordTimestamps.removeAll()
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
}
