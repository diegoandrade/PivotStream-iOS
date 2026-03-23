import SwiftUI

struct ChaptersView: View {
    @Bindable var vm: ReaderViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Group {
                if vm.chapters.isEmpty {
                    ContentUnavailableView(
                        "No Chapters",
                        systemImage: "list.bullet",
                        description: Text("Import an EPUB or PDF to see chapters here.")
                    )
                } else {
                    List {
                        ForEach(Array(vm.chapters.enumerated()), id: \.offset) { index, chapter in
                            Button {
                                vm.jumpToChapter(index)
                                isPresented = false
                            } label: {
                                HStack(spacing: 0) {
                                    // Indent based on level
                                    if chapter.level > 0 {
                                        Color.clear.frame(width: CGFloat(chapter.level) * 16)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(chapter.title)
                                            .font(chapter.level == 0 ? .body : .subheadline)
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(2)
                                        Text("\(chapter.startIndex) words in")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if vm.activeChapterIndex == index {
                                        Image(systemName: "play.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.orpAccent)
                                    }
                                }
                            }
                            .listRowBackground(
                                vm.activeChapterIndex == index
                                    ? Color.orpAccent.opacity(0.08)
                                    : Color.clear
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(vm.chapterMode == .pdf ? "Sections" : "Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}
