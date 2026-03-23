import Foundation

struct Token: Identifiable {
    let id = UUID()
    let core: String
    let prefix: String
    let suffix: String
    let orpIndex: Int
    let pauseMult: Double

    // Parts for ORP-aligned display
    var left: String { orpIndex > 0 ? String(core.prefix(orpIndex)) : "" }
    var pivot: String {
        guard orpIndex < core.count else { return core.last.map(String.init) ?? "" }
        return String(core[core.index(core.startIndex, offsetBy: orpIndex)])
    }
    var right: String {
        let afterPivot = orpIndex + 1
        guard afterPivot < core.count else { return "" }
        return String(core[core.index(core.startIndex, offsetBy: afterPivot)...])
    }
}
