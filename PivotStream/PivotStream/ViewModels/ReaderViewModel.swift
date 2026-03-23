import Foundation
import SwiftUI

enum MetaMode { case words, percent }
enum ChapterMode { case none, epub, pdf }

@Observable
class ReaderViewModel {

    // MARK: - Engine (source of truth for playback)

    let engine = RSVPEngine()

    // MARK: - State

    var chapters: [Chapter] = []
    var activeChapterIndex: Int? = nil
    var rawText: String = ""
    var statusMessage: String = ""
    var isLoading: Bool = false
    var metaMode: MetaMode = .words
    var chapterMode: ChapterMode = .none

    // Forwarded from engine for convenience
    var tokens: [Token] { engine.tokens }
    var currentIndex: Int { engine.currentIndex }
    var isPlaying: Bool { engine.isPlaying }
    var wpm: Double {
        get { engine.wpm }
        set { engine.wpm = newValue }
    }
    var rampEnabled: Bool { engine.rampEnabled }
    var currentToken: Token? { engine.currentToken }

    // MARK: - Init

    init() {
        engine.onAdvance = { [weak self] index in
            self?.updateActiveChapter(at: index)
        }
    }

    // MARK: - Playback

    func play()    { engine.start() }
    func pause()   { engine.pause() }
    func resume()  { engine.resume() }
    func restart() { engine.stop(); engine.start() }
    func toggleRamp() { engine.toggleRamp() }

    func jumpWords(_ delta: Int) {
        engine.jump(by: delta)
        updateActiveChapter(at: engine.currentIndex)
    }

    func jumpToChapter(_ index: Int) {
        guard index < chapters.count else { return }
        engine.seek(to: chapters[index].startIndex)
        activeChapterIndex = index
    }

    // MARK: - Meta

    func toggleMetaMode() {
        metaMode = metaMode == .words ? .percent : .words
    }

    var metaLabel: String {
        let count = engine.tokens.count
        guard count > 0 else { return "" }
        switch metaMode {
        case .words:   return "\(engine.currentIndex + 1) / \(count)"
        case .percent: return "\(Int(engine.progress * 100))%"
        }
    }

    // MARK: - Text loading

    func loadText(_ text: String) {
        engine.stop()
        rawText = text
        let parsed = TextParser.parse(text)
        engine.load(parsed)
        chapters = []
        chapterMode = .none
        activeChapterIndex = nil
        statusMessage = parsed.isEmpty ? "No readable words found." : "\(parsed.count) words"
    }

    func loadSample() {
        let sample = """
        Welcome to PivotStream, a rapid serial visual presentation reader. \
        Words appear one at a time at the center of your screen. \
        Your eyes stay fixed while text flows through a single focal point. \
        This technique can dramatically increase your reading speed. \
        The highlighted letter in red marks the Optimal Recognition Point. \
        Your brain anchors on this character to recognize the entire word instantly. \
        Try adjusting the words per minute slider to find your ideal pace. \
        You can import EPUB books or PDF documents using the input panel. \
        Jump forward or backward ten words at a time using the navigation buttons. \
        The speed ramp feature gradually increases your pace as you read. \
        Tap Stable to lock your speed and prevent automatic increases.
        """
        loadText(sample)
    }

    @MainActor
    func loadEPUB(url: URL) async {
        isLoading = true
        statusMessage = "Loading EPUB…"
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try EPUBParser.parse(url: url)
            }.value
            engine.stop()
            rawText = result.text
            engine.load(TextParser.parse(result.text))
            chapters = result.chapters
            chapterMode = .epub
            activeChapterIndex = nil
            statusMessage = "\(engine.tokens.count) words · \(chapters.count) chapters"
        } catch {
            statusMessage = "EPUB error: \(error.localizedDescription)"
        }
        isLoading = false
    }

    @MainActor
    func loadPDF(url: URL) async {
        isLoading = true
        statusMessage = "Loading PDF…"
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try PDFParser.parse(url: url)
            }.value
            engine.stop()
            rawText = result.text
            engine.load(TextParser.parse(result.text))
            chapters = result.chapters
            chapterMode = .pdf
            activeChapterIndex = nil
            let chapLabel = result.chapters.isEmpty ? "\(result.pageCount) pages" : "\(result.chapters.count) sections"
            statusMessage = "\(engine.tokens.count) words · \(chapLabel)"
        } catch {
            statusMessage = "PDF error: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Private

    private func updateActiveChapter(at index: Int) {
        guard !chapters.isEmpty else { return }
        for i in stride(from: chapters.count - 1, through: 0, by: -1) {
            if index >= chapters[i].startIndex {
                activeChapterIndex = i
                return
            }
        }
        activeChapterIndex = 0
    }

    // MARK: - Deep link / Share Extension

    /// Called on launch to pick up text saved by the Share Extension via App Group.
    func checkPendingSharedText() {
        guard let defaults = UserDefaults(suiteName: "group.com.yourname.pivotstream"),
              let text = defaults.string(forKey: "pendingText"), !text.isEmpty else { return }
        defaults.removeObject(forKey: "pendingText")
        loadText(text)
    }

    /// Handles `pivotstream://read?text=...` URLs from the Share Extension.
    func handleOpenURL(_ url: URL) {
        guard url.scheme == "pivotstream",
              url.host == "read",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let textParam = components.queryItems?.first(where: { $0.name == "text" })?.value,
              !textParam.isEmpty
        else { return }
        loadText(textParam)
    }
}
