import Foundation

struct Chapter: Identifiable {
    let id = UUID()
    let title: String
    let startIndex: Int
    let level: Int
}
