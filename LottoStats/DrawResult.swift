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
    
    static let samples: [DrawResult] = [
        DrawResult(
            gameName: "Lotto",
            drawDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 10)) ?? Date(),
            numbers: [3, 12, 19, 25, 34, 47]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 8)) ?? Date(),
            numbers: [5, 11, 18, 22, 36, 41]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 6)) ?? Date(),
            numbers: [1, 9, 17, 29, 33, 48]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 3)) ?? Date(),
            numbers: [7, 14, 21, 28, 35, 42]
        )
    ]
}
