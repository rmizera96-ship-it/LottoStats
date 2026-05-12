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
        drawDate: makeDate(year: 2026, month: 5, day: 10),
        numbers: [3, 12, 19, 25, 34, 47]
    )
    
    static let nextDrawDate = makeDate(year: 2026, month: 5, day: 14)
    
    static let samples: [DrawResult] = [
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 10),
            numbers: [3, 12, 19, 25, 34, 47]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 8),
            numbers: [5, 12, 18, 25, 36, 41]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 6),
            numbers: [3, 9, 17, 25, 33, 48]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 3),
            numbers: [7, 12, 21, 28, 34, 42]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 1),
            numbers: [3, 11, 19, 25, 31, 47]
        )
    ]
    
    static func result(for gameName: String, drawDate: Date) -> DrawResult? {
        samples.first { result in
            result.gameName == gameName &&
            Calendar.current.isDate(result.drawDate, inSameDayAs: drawDate)
        }
    }
    
    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? Date()
    }
}
