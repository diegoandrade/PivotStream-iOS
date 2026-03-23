import SwiftUI

struct ControlsView: View {
    @Bindable var vm: ReaderViewModel

    var body: some View {
        VStack(spacing: 16) {
            // WPM slider
            VStack(spacing: 4) {
                HStack {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(vm.wpm)) WPM")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $vm.wpm, in: 100...1600, step: 10)
                    .tint(Color.orpAccent)
            }

            // Main playback buttons
            HStack(spacing: 12) {
                Button {
                    vm.jumpWords(-10)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                        Text("10")
                            .font(.system(size: 10, weight: .bold))
                            .offset(y: -4)
                    }
                }
                .buttonStyle(ControlButtonStyle(isDestructive: false))
                .accessibilityLabel("Back 10 words")

                // Play / Pause
                if vm.isPlaying {
                    Button { vm.pause() } label: {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if vm.currentIndex > 0 && !vm.tokens.isEmpty {
                    Button { vm.resume() } label: {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button { vm.play() } label: {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(vm.tokens.isEmpty)
                }

                Button {
                    vm.jumpWords(10)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .semibold))
                        Text("10")
                            .font(.system(size: 10, weight: .bold))
                            .offset(y: -4)
                    }
                }
                .buttonStyle(ControlButtonStyle(isDestructive: false))
                .accessibilityLabel("Forward 10 words")
            }

            // Secondary buttons
            HStack(spacing: 10) {
                Button {
                    vm.restart()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    vm.toggleRamp()
                } label: {
                    Label(vm.rampEnabled ? "Ramp On" : "Stable", systemImage: vm.rampEnabled ? "speedometer" : "lock")
                        .font(.caption)
                }
                .buttonStyle(SecondaryButtonStyle(isActive: !vm.rampEnabled))

                Button {
                    vm.toggleMetaMode()
                } label: {
                    Text(vm.metaLabel.isEmpty ? "—" : vm.metaLabel)
                        .font(.caption.monospacedDigit())
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 56, height: 56)
            .background(Color.primary)
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ControlButtonStyle: ButtonStyle {
    let isDestructive: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .frame(width: 48, height: 48)
            .background(Color.secondary.opacity(0.12))
            .foregroundStyle(isDestructive ? Color.orpAccent : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isActive: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? Color.orpAccent.opacity(0.15) : Color.secondary.opacity(0.1))
            .foregroundStyle(isActive ? Color.orpAccent : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
