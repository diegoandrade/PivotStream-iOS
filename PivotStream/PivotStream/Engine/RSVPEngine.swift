import Foundation

/// Core RSVP playback engine. Handles timing, word advancement, and speed ramp.
/// Drives the ReaderViewModel — call start/pause/resume/restart to control playback.
@Observable
class RSVPEngine {

    // MARK: - State

    var tokens: [Token] = []
    var currentIndex: Int = 0
    var isPlaying: Bool = false
    var wpm: Double = 300
    var rampEnabled: Bool = true

    // Callback fired on each word advance (main actor)
    var onAdvance: ((Int) -> Void)?

    // MARK: - Public API

    func load(_ tokens: [Token]) {
        stop()
        self.tokens = tokens
        currentIndex = 0
    }

    func start() {
        guard !tokens.isEmpty else { return }
        isPlaying = true
        launchPlaybackTask()
        if rampEnabled { launchRampTask() }
    }

    func pause() {
        isPlaying = false
        cancelAll()
    }

    func resume() {
        guard !tokens.isEmpty else { return }
        isPlaying = true
        launchPlaybackTask()
        if rampEnabled { launchRampTask() }
    }

    func stop() {
        isPlaying = false
        cancelAll()
        currentIndex = 0
    }

    func seek(to index: Int) {
        let wasPlaying = isPlaying
        cancelAll()
        currentIndex = max(0, min(tokens.count - 1, index))
        if wasPlaying {
            isPlaying = true
            launchPlaybackTask()
            if rampEnabled { launchRampTask() }
        }
    }

    func jump(by delta: Int) {
        seek(to: currentIndex + delta)
    }

    func toggleRamp() {
        rampEnabled.toggle()
        if !rampEnabled {
            rampTask?.cancel()
            rampTask = nil
        } else if isPlaying {
            launchRampTask()
        }
    }

    // MARK: - Computed

    var currentToken: Token? {
        guard !tokens.isEmpty, currentIndex < tokens.count else { return nil }
        return tokens[currentIndex]
    }

    var progress: Double {
        guard tokens.count > 1 else { return 0 }
        return Double(currentIndex) / Double(tokens.count - 1)
    }

    /// Delay in milliseconds for the current token at the current WPM.
    var currentDelayMs: Double {
        guard let token = currentToken else { return 60_000 / wpm }
        return (60_000 / wpm) * token.pauseMult
    }

    // MARK: - Private

    private var playbackTask: Task<Void, Never>?
    private var rampTask: Task<Void, Never>?

    private func launchPlaybackTask() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            while !Task.isCancelled && isPlaying && currentIndex < tokens.count {
                let token = tokens[currentIndex]
                let delayMs = (60_000.0 / wpm) * token.pauseMult
                do {
                    try await Task.sleep(for: .milliseconds(delayMs))
                } catch {
                    break
                }
                guard !Task.isCancelled && isPlaying else { break }
                currentIndex += 1
                onAdvance?(currentIndex)
            }
            if currentIndex >= tokens.count && !tokens.isEmpty {
                isPlaying = false
                currentIndex = max(0, tokens.count - 1)
                rampTask?.cancel()
            }
        }
    }

    private func launchRampTask() {
        rampTask?.cancel()
        rampTask = Task { @MainActor in
            while !Task.isCancelled && isPlaying && rampEnabled {
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    break
                }
                guard !Task.isCancelled && isPlaying && rampEnabled else { break }
                wpm = min(wpm + 10, 1600)
            }
        }
    }

    private func cancelAll() {
        playbackTask?.cancel()
        playbackTask = nil
        rampTask?.cancel()
        rampTask = nil
    }
}
