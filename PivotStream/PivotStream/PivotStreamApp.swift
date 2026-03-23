import SwiftUI

@main
struct PivotStreamApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Thin wrapper so we can hold a shared ViewModel and handle deep links at the scene level.
private struct RootView: View {
    @State private var vm = ReaderViewModel()

    var body: some View {
        ContentView(vm: vm)
            .onAppear { vm.checkPendingSharedText() }
            .onOpenURL { vm.handleOpenURL($0) }
    }
}
