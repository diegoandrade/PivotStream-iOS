//
//  ContentView.swift
//  PivotStream
//
//  Created by Diego Andrade on 3/20/26.
//

import SwiftUI

struct ContentView: View {
    var vm: ReaderViewModel
    @State private var showInput = false
    @State private var showChapters = false
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // RSVP display
                RSVPView(token: currentToken)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Controls
                ControlsView(vm: vm)

                Spacer()

                // Bottom action row
                HStack(spacing: 16) {
                    Button {
                        showInput = true
                    } label: {
                        Label("Input", systemImage: "text.cursor")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if vm.chapterMode != .none {
                        Button {
                            showChapters = true
                        } label: {
                            Label(
                                vm.chapterMode == .pdf ? "Sections" : "Chapters",
                                systemImage: "list.bullet"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .overlay(
                            vm.activeChapterIndex != nil
                                ? RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orpAccent.opacity(0.5), lineWidth: 1)
                                : nil
                        )
                    }

                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("PivotStream")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showInput) {
            InputPanelView(vm: vm, isPresented: $showInput)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showChapters) {
            ChaptersView(vm: vm, isPresented: $showChapters)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHelp) {
            HelpView(isPresented: $showHelp)
                .presentationDetents([.medium])
        }
        .onAppear {
            vm.loadSample()
        }
    }

    private var currentToken: Token? {
        guard !vm.tokens.isEmpty, vm.currentIndex < vm.tokens.count else { return nil }
        return vm.tokens[vm.currentIndex]
    }
}

// MARK: - Help sheet

struct HelpView: View {
    @Binding var isPresented: Bool

    private let shortcuts: [(String, String)] = [
        ("Play / Pause", "Tap the large play button"),
        ("Restart", "Tap Restart"),
        ("Back 10 words", "Tap ⏮ or swipe left"),
        ("Forward 10 words", "Tap ⏭ or swipe right"),
        ("Speed", "Use the WPM slider"),
        ("Speed ramp", "Tap Ramp On / Stable to toggle"),
        ("Meta display", "Tap the counter to switch words / %"),
        ("Import EPUB", "Tap Input → Import EPUB"),
        ("Import PDF", "Tap Input → Import PDF"),
        ("Chapters", "Tap Chapters after import"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("How to use PivotStream") {
                    ForEach(shortcuts, id: \.0) { action, desc in
                        HStack {
                            Text(action)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("About RSVP") {
                    Text("""
                    Rapid Serial Visual Presentation displays one word at a time at a fixed focal point. \
                    The red letter marks the Optimal Recognition Point (ORP) — \
                    the character your brain uses to instantly recognize the whole word. \
                    Keeping your eyes still eliminates the saccadic movement that slows traditional reading.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

#Preview {
    ContentView(vm: ReaderViewModel())
}
