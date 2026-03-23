import SwiftUI
import UniformTypeIdentifiers

struct InputPanelView: View {
    @Bindable var vm: ReaderViewModel
    @Binding var isPresented: Bool

    @State private var showEPUBPicker = false
    @State private var showPDFPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $vm.rawText)
                    .font(.body)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .padding()

                Divider()

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            vm.loadSample()
                            isPresented = false
                        } label: {
                            Label("Load Sample", systemImage: "text.quote")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            vm.loadText(vm.rawText)
                            isPresented = false
                        } label: {
                            Label("Use Text", systemImage: "checkmark")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.orpAccent)
                        .disabled(vm.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    HStack(spacing: 12) {
                        Button { showEPUBPicker = true } label: {
                            Label("Import EPUB", systemImage: "book")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button { showPDFPicker = true } label: {
                            Label("Import PDF", systemImage: "doc.fill")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Sample books bundled in the app
                    HStack(spacing: 12) {
                        Button {
                            loadBundledEPUB()
                        } label: {
                            Label("Sample EPUB", systemImage: "book.pages")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            loadBundledPDF()
                        } label: {
                            Label("Sample PDF", systemImage: "doc.text")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if vm.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(vm.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !vm.statusMessage.isEmpty {
                        Text(vm.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        // EPUB file picker — copies to temp dir for stable access
        .fileImporter(
            isPresented: $showEPUBPicker,
            allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            importFile(result: result) { url in
                Task { await vm.loadEPUB(url: url); isPresented = false }
            }
        }
        // PDF file picker
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            importFile(result: result) { url in
                Task { await vm.loadPDF(url: url); isPresented = false }
            }
        }
    }

    // MARK: - Bundled samples

    private func loadBundledEPUB() {
        guard let url = Bundle.main.url(
            forResource: "austen-pride-and-prejudice-illustrations",
            withExtension: "epub"
        ) else {
            vm.statusMessage = "Bundled EPUB not found"
            return
        }
        Task { await vm.loadEPUB(url: url); isPresented = false }
    }

    private func loadBundledPDF() {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "pdf") else {
            vm.statusMessage = "Bundled PDF not found"
            return
        }
        Task { await vm.loadPDF(url: url); isPresented = false }
    }

    // MARK: - Security-scoped import helper

    private func importFile(result: Result<[URL], Error>, handler: @escaping (URL) -> Void) {
        guard case .success(let urls) = result, let source = urls.first else {
            vm.statusMessage = "Could not access file"
            return
        }

        // Security-scoped access must be claimed before reading
        let accessed = source.startAccessingSecurityScopedResource()

        // Copy to a temp location so we own the file
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.pathExtension)

        do {
            try FileManager.default.copyItem(at: source, to: temp)
            if accessed { source.stopAccessingSecurityScopedResource() }
            handler(temp)
        } catch {
            if accessed { source.stopAccessingSecurityScopedResource() }
            vm.statusMessage = "Import error: \(error.localizedDescription)"
        }
    }
}
