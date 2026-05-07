import Foundation
import Speech
import AVFoundation
import Combine
import CoreAudio

// MARK: - AudioInputDevice (Feature 11)

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String

    static func allInputDevices() -> [AudioInputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else { return [] }

        var result: [AudioInputDevice] = []
        for deviceID in deviceIDs {
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &streamSize) == noErr, streamSize > 0 else { continue }

            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid) == noErr else { continue }

            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) == noErr else { continue }

            result.append(AudioInputDevice(id: deviceID, uid: uid as String, name: name as String))
        }
        return result
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        allInputDevices().first(where: { $0.uid == uid })?.id
    }
}

// MARK: - SpeechRecognitionManager
// Upgraded with word-level tracking, silence detection, and fuzzy matching
// Ported from Textream's SpeechRecognizer for parity.

final class SpeechRecognitionManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var lastSpokenWords: String = ""
    @Published var wordsPerMinute: Double = 0
    @Published var recognizedCharCount: Int = 0
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @Published var shouldDismiss: Bool = false
    @Published var shouldAdvancePage: Bool = false

    /// True when recent audio levels indicate the user is actively speaking
    var isSpeaking: Bool {
        let recent = audioLevels.suffix(10)
        guard !recent.isEmpty else { return false }
        let avg = recent.reduce(0, +) / CGFloat(recent.count)
        return avg > 0.08
    }

    var onSpeechDetected: ((Double) -> Void)?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    // Word tracking state
    private var sourceText: String = ""
    private var normalizedSource: String = ""
    private var matchStartOffset: Int = 0
    private var retryCount: Int = 0
    private let maxRetries: Int = 10
    private var configurationChangeObserver: Any?
    private var pendingRestart: DispatchWorkItem?
    private var sessionGeneration: Int = 0

    // Legacy WPM tracking
    private var wordTimestamps: [(word: String, time: Date)] = []

    // MARK: - Public API

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

    /// Start word-tracking mode with a source text to match against
    func startWordTracking(with text: String) {
        cleanupRecognition()

        let words = splitTextIntoWords(text)
        let collapsed = words.joined(separator: " ")
        sourceText = collapsed
        normalizedSource = Self.normalize(collapsed)
        recognizedCharCount = 0
        matchStartOffset = 0
        retryCount = 0
        shouldDismiss = false
        shouldAdvancePage = false
        sessionGeneration += 1

        requestAuthAndBegin()
    }

    /// Start classic voice-scroll mode (just detects WPM, no word tracking)
    func startListening() {
        if authorizationStatus == .notDetermined {
            requestAuthorization { [weak self] in self?.startListening() }
            return
        }
        let locale = UserDefaults.standard.string(forKey: "speech.locale") ?? "en-US"
        guard authorizationStatus == .authorized,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.isAvailable else { return }

        stopListening()
        sourceText = ""
        sessionGeneration += 1

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevels(buffer: buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch { return }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
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
                DispatchQueue.main.async { self.lastSpokenWords = text }
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

    func stop() {
        isListening = false
        cleanupRecognition()
    }

    func forceStop() {
        isListening = false
        sourceText = ""
        retryCount = maxRetries
        cleanupRecognition()
    }

    func resume() {
        retryCount = 0
        matchStartOffset = recognizedCharCount
        shouldDismiss = false
        beginRecognition()
    }

    func toggleListening() {
        if isListening { stopListening() } else { startListening() }
    }

    /// Jump highlight to a specific char offset (tap-to-jump)
    func jumpTo(charOffset: Int) {
        recognizedCharCount = charOffset
        matchStartOffset = charOffset
        retryCount = 0
        if isListening { restartRecognition() }
    }

    // MARK: - Private

    private func requestAuthAndBegin() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.requestSpeechAuthAndBegin() }
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

    private func requestSpeechAuthAndBegin() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status == .authorized { self?.beginRecognition() }
            }
        }
    }

    private func cleanupRecognition() {
        pendingRestart?.cancel()
        pendingRestart = nil
        if let observer = configurationChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationChangeObserver = nil
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func scheduleBeginRecognition(after delay: TimeInterval) {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingRestart = nil
            self?.beginRecognition()
        }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func beginRecognition() {
        cleanupRecognition()
        audioEngine = AVAudioEngine()

        let locale = UserDefaults.standard.string(forKey: "speech.locale") ?? "en-US"
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        // Apply selected microphone if configured (Feature 11)
        let micUID = UserDefaults.standard.string(forKey: "speech.micUID") ?? ""
        if !micUID.isEmpty, let deviceID = AudioInputDevice.deviceID(forUID: micUID) {
            if let audioUnit = audioEngine.inputNode.audioUnit {
                var devID = deviceID
                AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &devID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                AudioUnitUninitialize(audioUnit)
                AudioUnitInitialize(audioUnit)
            }
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.5)
            }
            return
        }

        let monoFormat = AVAudioFormat(
            commonFormat: hardwareFormat.commonFormat,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: hardwareFormat.isInterleaved
        )
        let tapFormat = (hardwareFormat.channelCount > 1) ? monoFormat : hardwareFormat

        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.sourceText.isEmpty else { return }
            self.restartRecognition()
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            self?.updateAudioLevels(buffer: buffer)
        }

        let currentGeneration = sessionGeneration
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    guard self.sessionGeneration == currentGeneration else { return }
                    self.retryCount = 0
                    self.lastSpokenWords = spoken
                    if !self.sourceText.isEmpty {
                        self.matchCharacters(spoken: spoken)
                    } else {
                        // Legacy WPM mode
                        let words = spoken.split(separator: " ")
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
                                    self.wordsPerMinute = wpm
                                    self.onSpeechDetected?(wpm)
                                }
                            }
                        }
                    }
                }
            }
            if error != nil {
                DispatchQueue.main.async {
                    guard self.recognitionRequest != nil else { return }
                    if self.isListening && !self.shouldDismiss && !self.sourceText.isEmpty && self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        let delay = min(Double(self.retryCount) * 0.5, 1.5)
                        self.scheduleBeginRecognition(after: delay)
                    } else {
                        self.isListening = false
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.5)
            } else {
                isListening = false
            }
        }
    }

    private func restartRecognition() {
        retryCount = 0
        isListening = true
        cleanupRecognition()
        scheduleBeginRecognition(after: 0.5)
    }

    private func updateAudioLevels(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength { sum += channelData[i] * channelData[i] }
        let rms = sqrt(sum / Float(max(frameLength, 1)))
        let level = CGFloat(min(rms * 5, 1.0))
        DispatchQueue.main.async {
            self.audioLevels.append(level)
            if self.audioLevels.count > 30 { self.audioLevels.removeFirst() }
        }
    }

    // MARK: - Fuzzy Character-Level Matching (ported from Textream)

    private func matchCharacters(spoken: String) {
        let charResult = charLevelMatch(spoken: spoken)
        let wordResult = wordLevelMatch(spoken: spoken)
        let best = max(charResult, wordResult)
        let newCount = matchStartOffset + best
        if newCount > recognizedCharCount {
            recognizedCharCount = min(newCount, sourceText.count)
        }
    }

    private func charLevelMatch(spoken: String) -> Int {
        let remainingSource = String(sourceText.dropFirst(matchStartOffset))
        let src = Array(remainingSource.lowercased().unicodeScalars).map { Character($0) }
        let spk = Array(Self.normalize(spoken).unicodeScalars).map { Character($0) }

        var si = 0, ri = 0, lastGoodOrigIndex = 0

        while si < src.count && ri < spk.count {
            let sc = src[si], rc = spk[ri]
            if !sc.isLetter && !sc.isNumber { si += 1; continue }
            if !rc.isLetter && !rc.isNumber { ri += 1; continue }

            if sc == rc {
                si += 1; ri += 1; lastGoodOrigIndex = si
            } else {
                var found = false
                let maxSkipR = min(3, spk.count - ri - 1)
                if maxSkipR >= 1 {
                    for skipR in 1...maxSkipR {
                        if ri + skipR < spk.count && spk[ri + skipR] == sc {
                            ri = ri + skipR; found = true; break
                        }
                    }
                }
                if found { continue }
                let maxSkipS = min(3, src.count - si - 1)
                if maxSkipS >= 1 {
                    for skipS in 1...maxSkipS {
                        if si + skipS < src.count && src[si + skipS] == rc {
                            si = si + skipS; found = true; break
                        }
                    }
                }
                if found { continue }
                si += 1; ri += 1; lastGoodOrigIndex = si
            }
        }
        return lastGoodOrigIndex
    }

    private static func isAnnotationWord(_ word: String) -> Bool {
        if word.hasPrefix("[") && word.hasSuffix("]") { return true }
        return word.filter { $0.isLetter || $0.isNumber }.isEmpty
    }

    private func wordLevelMatch(spoken: String) -> Int {
        let remainingSource = String(sourceText.dropFirst(matchStartOffset))
        let sourceWords = remainingSource.split(separator: " ").map { String($0) }
        let spokenWords = spoken.lowercased().split(separator: " ").map { String($0) }

        var si = 0, ri = 0, matchedCharCount = 0

        while si < sourceWords.count && ri < spokenWords.count {
            if Self.isAnnotationWord(sourceWords[si]) {
                matchedCharCount += sourceWords[si].count
                if si < sourceWords.count - 1 { matchedCharCount += 1 }
                si += 1; continue
            }

            let srcWord = sourceWords[si].lowercased().filter { $0.isLetter || $0.isNumber }
            let spkWord = spokenWords[ri].filter { $0.isLetter || $0.isNumber }

            if srcWord == spkWord || isFuzzyMatch(srcWord, spkWord) {
                matchedCharCount += sourceWords[si].count
                if si < sourceWords.count - 1 { matchedCharCount += 1 }
                si += 1; ri += 1
            } else {
                var foundSpk = false
                let maxSpkSkip = min(3, spokenWords.count - ri - 1)
                for skip in 1...max(1, maxSpkSkip) where skip <= maxSpkSkip {
                    let nextSpk = spokenWords[ri + skip].filter { $0.isLetter || $0.isNumber }
                    if srcWord == nextSpk || isFuzzyMatch(srcWord, nextSpk) {
                        ri += skip; foundSpk = true; break
                    }
                }
                if foundSpk { continue }

                var foundSrc = false
                let maxSrcSkip = min(3, sourceWords.count - si - 1)
                for skip in 1...max(1, maxSrcSkip) where skip <= maxSrcSkip {
                    let nextSrc = sourceWords[si + skip].lowercased().filter { $0.isLetter || $0.isNumber }
                    if nextSrc == spkWord || isFuzzyMatch(nextSrc, spkWord) {
                        for s in 0..<skip { matchedCharCount += sourceWords[si + s].count + 1 }
                        si += skip; foundSrc = true; break
                    }
                }
                if foundSrc { continue }

                if srcWord.isEmpty {
                    matchedCharCount += sourceWords[si].count
                    if si < sourceWords.count - 1 { matchedCharCount += 1 }
                    si += 1; continue
                }
                ri += 1
            }
        }

        while si < sourceWords.count && Self.isAnnotationWord(sourceWords[si]) {
            matchedCharCount += sourceWords[si].count
            if si < sourceWords.count - 1 { matchedCharCount += 1 }
            si += 1
        }

        return matchedCharCount
    }

    private func isFuzzyMatch(_ a: String, _ b: String) -> Bool {
        if a.isEmpty || b.isEmpty { return false }
        if a == b { return true }
        if a.hasPrefix(b) || b.hasPrefix(a) { return true }
        if a.contains(b) || b.contains(a) { return true }
        let shared = zip(a, b).prefix(while: { $0 == $1 }).count
        let shorter = min(a.count, b.count)
        if shorter >= 2 && shared >= max(2, shorter * 3 / 5) { return true }
        let dist = editDistance(a, b)
        if shorter <= 4 { return dist <= 1 }
        if shorter <= 8 { return dist <= 2 }
        return dist <= max(a.count, b.count) / 3
    }

    private func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]; dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : min(prev, dp[j], dp[j-1]) + 1
                prev = temp
            }
        }
        return dp[b.count]
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }
}
