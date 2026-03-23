import SwiftUI

struct RSVPView: View {
    let token: Token?

    // Fixed character slots for ORP alignment (monospaced)
    private let fontSize: CGFloat = 44
    private let leftSlots: CGFloat = 4
    private let rightSlots: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            // Focus window with ORP guides
            ZStack {
                // Guide lines
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.orpAccent.opacity(0.15))
                        .frame(width: 2)
                    Spacer()
                }
                .padding(.leading, slotWidth * leftSlots)

                // Word display
                HStack(spacing: 0) {
                    Group {
                        Text(token?.prefix ?? "")
                            .foregroundStyle(Color.secondary) +
                        Text(token?.left ?? "")
                            .foregroundStyle(Color.primary)
                    }
                    .frame(width: slotWidth * leftSlots, alignment: .trailing)
                    .lineLimit(1)

                    Text(token?.pivot ?? "·")
                        .foregroundStyle(Color.orpAccent)
                        .fontWeight(.bold)
                        .frame(minWidth: slotWidth)

                    Group {
                        Text(token?.right ?? "")
                            .foregroundStyle(Color.primary) +
                        Text(token?.suffix ?? "")
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(width: slotWidth * rightSlots, alignment: .leading)
                    .lineLimit(1)
                }
            }
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .frame(height: fontSize * 1.6)
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.readerBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var slotWidth: CGFloat {
        // Approximate monospaced character width at given font size
        fontSize * 0.6
    }
}

#Preview {
    RSVPView(token: Token(core: "Hello", prefix: "", suffix: ",", orpIndex: 1, pauseMult: 1.4))
        .padding()
}
