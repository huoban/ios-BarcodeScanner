import AVFoundation
import AudioToolbox
import Foundation

/// 与 Android SoundPlayer 参数一致的原生提示音合成
enum SoundPlayer {
    static func play(preferences: Preferences) {
        guard preferences.soundEnabled else { return }
        let frequency = Double(preferences.soundFrequency) ?? 1000
        let durationMs = Double(preferences.soundLength) ?? 150
        let modulation = Double(preferences.soundModulation) ?? 0
        let volume = Double(preferences.soundVolume) ?? 80
        let sampleRate = 44100.0
        let frameCount = Int(max(0, durationMs) * sampleRate / 1000)
        guard frameCount > 0 else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        for index in 0..<frameCount {
            let time = Double(index) / sampleRate
            var currentFrequency = frequency
            if modulation > 0 {
                currentFrequency += sin(2 * Double.pi * time * modulation) * frequency * 0.5
            }
            let sample = sin(2 * Double.pi * time * currentFrequency) * (volume / 100)
            buffer.floatChannelData?[0][index] = Float(sample)
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [])
        try? session.activate()
        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            player.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + durationMs / 1000 + 0.1) {
                player.stop()
                engine.stop()
            }
        } catch {
            NSLog("play scan sound failed: \(error)")
        }
    }

    static func vibrate() {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    static func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}
