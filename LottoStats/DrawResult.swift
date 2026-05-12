import Foundation

struct DrawResult: Identifiable {
    let id = UUID()
    let gameName: String
    let drawDate: Date
    let numbers: [Int]
    let plusNumbers: [Int]?
}

extension DrawResult {
    static let sample = DrawResult(
        gameName: "Lotto",
        drawDate: makeDate(year: 2026, month: 5, day: 10),
        numbers: [3, 12, 19, 25, 34, 47],
        plusNumbers: [2, 8, 16, 24, 35, 44]
    )
    
    static let nextDrawDates: [Date] = [
        makeDate(year: 2026, month: 5, day: 14),
        makeDate(year: 2026, month: 5, day: 16),
        makeDate(year: 2026, month: 5, day: 18),
        makeDate(year: 2026, month: 5, day: 20),
        makeDate(year: 2026, month: 5, day: 22),
        makeDate(year: 2026, month: 5, day: 24),
        makeDate(year: 2026, month: 5, day: 26),
        makeDate(year: 2026, month: 5, day: 28),
        makeDate(year: 2026, month: 5, day: 30),
        makeDate(year: 2026, month: 6, day: 1)
    ]
    
    static let nextDrawDate = nextDrawDates.first ?? Date()
    
    static let samples: [DrawResult] = [
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 10),
            numbers: [3, 12, 19, 25, 34, 47],
            plusNumbers: [2, 8, 16, 24, 35, 44]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 8),
            numbers: [5, 12, 18, 25, 36, 41],
            plusNumbers: [1, 9, 14, 27, 33, 45]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 6),
            numbers: [3, 9, 17, 25, 33, 48],
            plusNumbers: [4, 12, 19, 28, 37, 49]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 3),
            numbers: [7, 12, 21, 28, 34, 42],
            plusNumbers: [6, 11, 18, 25, 31, 40]
        ),
        DrawResult(
            gameName: "Lotto",
            drawDate: makeDate(year: 2026, month: 5, day: 1),
            numbers: [3, 11, 19, 25, 31, 47],
            plusNumbers: [5, 13, 20, 26, 34, 48]
        )
    ]
    
    static func result(for gameName: String, drawDate: Date) -> DrawResult? {
        samples.first { result in
            result.gameName == gameName &&
            Calendar.current.isDate(result.drawDate, inSameDayAs: drawDate)
        }
    }
    
    static func upcomingDrawDates(count: Int) -> [Date] {
        Array(nextDrawDates.prefix(count))
    }
    
    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? Date()
    }
}
