import Foundation

struct DrawResult: Identifiable {
    let id = UUID()
    let gameName: String
    let drawDate: Date
    let numbers: [Int]
}

extension DrawResult {
    static let sample = DrawResult(
        gameName: "Lotto",
        drawDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 10)) ?? Date(),
        numbers: [3, 12, 19, 25, 34, 47]
    )
}
