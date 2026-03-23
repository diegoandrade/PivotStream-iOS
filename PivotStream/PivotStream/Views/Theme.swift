import SwiftUI

extension Color {
<<<<<<< HEAD
    // Red ORP accent — using Apple System Red directly
    static var orpAccent: Color { .rsvpRed }
    
    // Predefined red for RSVP (Apple System Red)
    static var rsvpRed: Color {
        Color(.sRGB, red: 1.0, green: 0.23, blue: 0.19, opacity: 1.0) // #FF3B30
    }
    
    // Darker red for dark mode
    static var rsvpRedDark: Color {
        Color(.sRGB, red: 1.0, green: 0.27, blue: 0.23, opacity: 1.0) // #FF453A
    }
=======
    // Red ORP accent — maps to the app's AccentColor asset (set to red in Assets.xcassets)
    static var orpAccent: Color { .accentColor }
>>>>>>> main

    // Reader background — slightly off-white/dark for warm feel
    // Uses SwiftUI's tertiarySystemBackground which is adaptive
    static var readerBackground: Color { Color.primary.opacity(0.04) }
<<<<<<< HEAD
    
    // Helper: Create color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

=======
}
>>>>>>> main
