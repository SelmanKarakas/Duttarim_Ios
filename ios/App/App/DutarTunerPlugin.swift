import Foundation
import AVFoundation
import UIKit
import Capacitor

@objc(DutarTunerPlugin)
public class DutarTunerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "DutarTunerPlugin"
    public let jsName = "DutarTuner"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "checkPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestPermissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "prepareReferencePlayback", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setAnalysisMuted", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openMicrophoneSettings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setNoteDetailOrientation", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setAppearance", returnType: CAPPluginReturnPromise)
    ]

    private let audioEngine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.duttarim.pitch", qos: .userInitiated)
    private let pendingLock = NSLock()
    private var pendingAnalysis = false
    private var isRunning = false
    private var mutedUntil: TimeInterval = 0
    private var analysisBuffer: [Float] = []
    private var stableFrequency: Double = 0
    private var candidateFrequency: Double = 0
    private var candidateFrames = 0
    private var lastReliablePitchAt: TimeInterval = 0

    private let analysisSize = 4096
    private let rmsThreshold = 0.0012
    private let minFrequency = 110.0
    private let maxFrequency = 500.0
    private let yinThreshold = 0.25

    @objc override public func checkPermissions(_ call: CAPPluginCall) {
        let status: String
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: status = "granted"
        case .denied, .restricted: status = "denied"
        case .notDetermined: status = "prompt"
        @unknown default: status = "prompt"
        }
        call.resolve(["microphone": status])
    }

    @objc override public func requestPermissions(_ call: CAPPluginCall) {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
            checkPermissions(call)
            return
        }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.checkPermissions(call) }
        }
    }

    @objc func openMicrophoneSettings(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url) else {
                call.reject("Unable to open application settings")
                return
            }
            UIApplication.shared.open(url)
            call.resolve()
        }
    }

    @objc func prepareReferencePlayback(_ call: CAPPluginCall) {
        // Reference tones also work before microphone access or after recording stops.
        // Keep the measurement session intact while the tuner is listening.
        do {
            if !isRunning {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            }
            call.resolve()
        } catch {
            call.reject("Unable to prepare reference audio: \(error.localizedDescription)")
        }
    }

    @objc func setAnalysisMuted(_ call: CAPPluginCall) {
        let muted = call.getBool("muted") ?? false
        analysisQueue.async { [weak self] in
            self?.mutedUntil = muted ? .greatestFiniteMagnitude : Date().timeIntervalSince1970 + 0.35
            DispatchQueue.main.async { call.resolve() }
        }
    }

    @objc func setNoteDetailOrientation(_ call: CAPPluginCall) {
        let allowRotation = call.getBool("allowRotation") ?? false
        DispatchQueue.main.async { [weak self] in
            if let controller = self?.bridge?.viewController as? MyViewController {
                controller.setNoteRotationAllowed(allowRotation)
            }
            call.resolve()
        }
    }

    @objc func setAppearance(_ call: CAPPluginCall) {
        let dark = call.getBool("dark") ?? false
        DispatchQueue.main.async { [weak self] in
            if let controller = self?.bridge?.viewController as? MyViewController {
                controller.setDarkAppearance(dark)
            }
            call.resolve()
        }
    }

    @objc func start(_ call: CAPPluginCall) {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            call.reject("Microphone permission is required")
            return
        }
        if isRunning {
            call.resolve(["started": true])
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.inputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                call.reject("Microphone input format is invalid")
                return
            }

            analysisQueue.sync {
                analysisBuffer.removeAll(keepingCapacity: true)
                stableFrequency = 0
                candidateFrequency = 0
                candidateFrames = 0
                lastReliablePitchAt = 0
                mutedUntil = 0
            }
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
                self?.enqueue(buffer: buffer, sampleRate: format.sampleRate)
            }
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
            call.resolve(["started": true, "sampleRate": format.sampleRate])
        } catch {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            try? session.setActive(false)
            call.reject("Failed to start microphone: \(error.localizedDescription)")
        }
    }

    @objc func stop(_ call: CAPPluginCall) {
        isRunning = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        call.resolve(["stopped": true])
    }

    private func enqueue(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard isRunning, let channel = buffer.floatChannelData?[0] else { return }
        pendingLock.lock()
        if pendingAnalysis {
            pendingLock.unlock()
            return
        }
        pendingAnalysis = true
        pendingLock.unlock()

        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        analysisQueue.async { [weak self] in
            guard let self else { return }
            defer {
                self.pendingLock.lock()
                self.pendingAnalysis = false
                self.pendingLock.unlock()
            }
            self.process(samples: samples, sampleRate: sampleRate)
        }
    }

    private func process(samples: [Float], sampleRate: Double) {
        guard isRunning else { return }
        analysisBuffer.append(contentsOf: samples)
        if analysisBuffer.count > analysisSize {
            analysisBuffer.removeFirst(analysisBuffer.count - analysisSize)
        }
        guard analysisBuffer.count == analysisSize else { return }

        let rms = sqrt(analysisBuffer.reduce(0.0) { $0 + Double($1 * $1) } / Double(analysisSize))
        let estimate = rms > rmsThreshold ? detectPitchYin(samples: analysisBuffer, sampleRate: sampleRate) : nil
        let rawFrequency = estimate?.frequency ?? 0
        let confidence = estimate?.confidence ?? 0
        let now = Date().timeIntervalSince1970
        if confidence >= 0.72 { lastReliablePitchAt = now }
        let reliable = confidence >= 0.72 ||
            (stableFrequency > 0 && now - lastReliablePitchAt <= 2.2 && confidence >= 0.50)
        let frequency = reliable ? stabilize(rawFrequency) : 0
        let output = now < mutedUntil ? 0 : frequency

        DispatchQueue.main.async { [weak self] in
            guard self?.isRunning == true else { return }
            self?.notifyListeners("pitch", data: [
                "frequency": output,
                "rawFrequency": rawFrequency,
                "confidence": confidence,
                "rms": rms
            ])
        }
    }

    private func stabilize(_ frequency: Double) -> Double {
        guard frequency > 0 else { return 0 }
        guard stableFrequency > 0 else {
            stableFrequency = frequency
            return frequency
        }
        let distance = abs(1200 * log2(frequency / stableFrequency))
        if distance <= 35 {
            candidateFrequency = 0
            candidateFrames = 0
            stableFrequency = stableFrequency * 0.65 + frequency * 0.35
            return stableFrequency
        }
        if candidateFrequency > 0 && abs(1200 * log2(frequency / candidateFrequency)) <= 40 {
            candidateFrames += 1
            candidateFrequency = candidateFrequency * 0.5 + frequency * 0.5
        } else {
            candidateFrequency = frequency
            candidateFrames = 1
        }
        let ratio = frequency / stableFrequency
        let harmonicJump = [0.5, 2.0, 1.0 / 3.0, 3.0].contains {
            abs(1200 * log2(ratio / $0)) < 45
        }
        if candidateFrames >= (harmonicJump ? 4 : 2) {
            stableFrequency = candidateFrequency
            candidateFrequency = 0
            candidateFrames = 0
            return stableFrequency
        }
        return 0
    }

    private func detectPitchYin(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        let minLag = max(2, Int(floor(sampleRate / maxFrequency)))
        let maxLag = min(samples.count / 2, Int(ceil(sampleRate / minFrequency)))
        guard maxLag > minLag + 2 else { return nil }
        let comparisonLength = samples.count - maxLag
        var yin = [Double](repeating: 0, count: maxLag + 1)
        for lag in 1...maxLag {
            var sum = 0.0
            for index in 0..<comparisonLength {
                let difference = Double(samples[index] - samples[index + lag])
                sum += difference * difference
            }
            yin[lag] = sum
        }
        var runningSum = 0.0
        for lag in 1...maxLag {
            runningSum += yin[lag]
            yin[lag] = runningSum > 0 ? yin[lag] * Double(lag) / runningSum : 1
        }
        var bestLag = -1
        var lag = minLag
        while lag < maxLag {
            if yin[lag] < yinThreshold {
                while lag + 1 < maxLag && yin[lag + 1] < yin[lag] { lag += 1 }
                bestLag = lag
                break
            }
            lag += 1
        }
        if bestLag < 0 {
            var bestValue = Double.greatestFiniteMagnitude
            for candidate in (minLag + 1)..<maxLag {
                if yin[candidate] <= yin[candidate - 1] &&
                   yin[candidate] <= yin[candidate + 1] && yin[candidate] < bestValue {
                    bestValue = yin[candidate]
                    bestLag = candidate
                }
            }
            guard bestLag > 0, bestValue <= 0.40 else { return nil }
        }
        let confidence = max(0, min(1, 1 - yin[bestLag]))
        let left = yin[max(1, bestLag - 1)]
        let middle = yin[bestLag]
        let right = yin[min(maxLag, bestLag + 1)]
        let denominator = 2 * middle - left - right
        var refinedLag = Double(bestLag)
        if denominator.isFinite && abs(denominator) > 1e-12 {
            let correction = (right - left) / (2 * denominator)
            if correction.isFinite && abs(correction) <= 1 { refinedLag += correction }
        }
        guard refinedLag > 0 else { return nil }
        let frequency = sampleRate / refinedLag
        guard frequency.isFinite, frequency >= minFrequency, frequency <= maxFrequency else { return nil }
        return (frequency, confidence)
    }
}
