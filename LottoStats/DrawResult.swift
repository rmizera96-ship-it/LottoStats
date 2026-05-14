import Foundation

struct DrawResult: Identifiable {
    let id = UUID()
    let drawSystemId: Int?
    let game: LottoGame
    let drawDate: Date
    let numbers: [Int]
    let plusNumbers: [Int]?
    let extraNumbers: [Int]?
    
    var gameName: String {
        game.displayName
    }
    
    init(
        drawSystemId: Int? = nil,
        game: LottoGame = .lotto,
        drawDate: Date,
        numbers: [Int],
        plusNumbers: [Int]? = nil,
        extraNumbers: [Int]? = nil
    ) {
        self.drawSystemId = drawSystemId
        self.game = game
        self.drawDate = drawDate
        self.numbers = numbers.sorted()
        self.plusNumbers = plusNumbers?.sorted()
        self.extraNumbers = extraNumbers?.sorted()
    }
}

extension DrawResult {
    static let sample = DrawResult(
        game: .lotto,
        drawDate: makeDate(year: 2026, month: 5, day: 10),
        numbers: [3, 12, 19, 25, 34, 47],
        plusNumbers: [2, 8, 16, 24, 35, 44]
    )
    
    static let lottoNextDrawDates: [Date] = [
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
    
    static let miniLottoNextDrawDates: [Date] = [
        makeDate(year: 2026, month: 5, day: 13),
        makeDate(year: 2026, month: 5, day: 14),
        makeDate(year: 2026, month: 5, day: 15),
        makeDate(year: 2026, month: 5, day: 16),
        makeDate(year: 2026, month: 5, day: 17),
        makeDate(year: 2026, month: 5, day: 18),
        makeDate(year: 2026, month: 5, day: 19),
        makeDate(year: 2026, month: 5, day: 20),
        makeDate(year: 2026, month: 5, day: 21),
        makeDate(year: 2026, month: 5, day: 22)
    ]
    
    static let eurojackpotNextDrawDates: [Date] = [
        makeDate(year: 2026, month: 5, day: 13),
        makeDate(year: 2026, month: 5, day: 16),
        makeDate(year: 2026, month: 5, day: 20),
        makeDate(year: 2026, month: 5, day: 23),
        makeDate(year: 2026, month: 5, day: 27),
        makeDate(year: 2026, month: 5, day: 30),
        makeDate(year: 2026, month: 6, day: 3),
        makeDate(year: 2026, month: 6, day: 6),
        makeDate(year: 2026, month: 6, day: 10),
        makeDate(year: 2026, month: 6, day: 13)
    ]
    
    static let nextDrawDates = lottoNextDrawDates
    static let nextDrawDate = lottoNextDrawDates.first ?? Date()
    
    static let samples: [DrawResult] = [
        DrawResult(
            game: .lotto,
            drawDate: makeDate(year: 2026, month: 5, day: 10),
            numbers: [3, 12, 19, 25, 34, 47],
            plusNumbers: [2, 8, 16, 24, 35, 44]
        ),
        DrawResult(
            game: .lotto,
            drawDate: makeDate(year: 2026, month: 5, day: 8),
            numbers: [5, 12, 18, 25, 36, 41],
            plusNumbers: [1, 9, 14, 27, 33, 45]
        ),
        DrawResult(
            game: .lotto,
            drawDate: makeDate(year: 2026, month: 5, day: 6),
            numbers: [3, 9, 17, 25, 33, 48],
            plusNumbers: [4, 12, 19, 28, 37, 49]
        ),
        DrawResult(
            game: .lotto,
            drawDate: makeDate(year: 2026, month: 5, day: 3),
            numbers: [7, 12, 21, 28, 34, 42],
            plusNumbers: [6, 11, 18, 25, 31, 40]
        ),
        DrawResult(
            game: .lotto,
            drawDate: makeDate(year: 2026, month: 5, day: 1),
            numbers: [3, 11, 19, 25, 31, 47],
            plusNumbers: [5, 13, 20, 26, 34, 48]
        ),
        
        DrawResult(
            game: .miniLotto,
            drawDate: makeDate(year: 2026, month: 5, day: 11),
            numbers: [4, 12, 19, 27, 38]
        ),
        DrawResult(
            game: .miniLotto,
            drawDate: makeDate(year: 2026, month: 5, day: 10),
            numbers: [2, 8, 12, 31, 40]
        ),
        DrawResult(
            game: .miniLotto,
            drawDate: makeDate(year: 2026, month: 5, day: 9),
            numbers: [5, 14, 22, 27, 41]
        ),
        DrawResult(
            game: .miniLotto,
            drawDate: makeDate(year: 2026, month: 5, day: 8),
            numbers: [1, 12, 18, 29, 33]
        ),
        DrawResult(
            game: .miniLotto,
            drawDate: makeDate(year: 2026, month: 5, day: 7),
            numbers: [4, 10, 19, 27, 35]
        ),
        
        DrawResult(
            game: .eurojackpot,
            drawDate: makeDate(year: 2026, month: 5, day: 9),
            numbers: [7, 14, 23, 36, 45],
            extraNumbers: [2, 11]
        ),
        DrawResult(
            game: .eurojackpot,
            drawDate: makeDate(year: 2026, month: 5, day: 6),
            numbers: [3, 18, 25, 34, 49],
            extraNumbers: [5, 9]
        ),
        DrawResult(
            game: .eurojackpot,
            drawDate: makeDate(year: 2026, month: 5, day: 2),
            numbers: [1, 12, 27, 33, 41],
            extraNumbers: [4, 10]
        ),
        DrawResult(
            game: .eurojackpot,
            drawDate: makeDate(year: 2026, month: 4, day: 29),
            numbers: [9, 16, 22, 38, 50],
            extraNumbers: [1, 12]
        )
    ]
    
    static func result(for game: LottoGame, drawDate: Date) -> DrawResult? {
        samples.first { result in
            result.game == game &&
            Calendar.current.isDate(result.drawDate, inSameDayAs: drawDate)
        }
    }
    
    static func result(for gameName: String, drawDate: Date) -> DrawResult? {
        guard let game = LottoGame.fromDisplayName(gameName) else {
            return nil
        }
        
        return result(for: game, drawDate: drawDate)
    }
    
    static func upcomingDrawDates(for game: LottoGame = .lotto, count: Int) -> [Date] {
        let dates: [Date]
        
        switch game {
        case .lotto:
            dates = lottoNextDrawDates
        case .miniLotto:
            dates = miniLottoNextDrawDates
        case .eurojackpot:
            dates = eurojackpotNextDrawDates
        }
        
        return Array(dates.prefix(count))
    }
    
    static func upcomingDrawDates(count: Int) -> [Date] {
        upcomingDrawDates(for: .lotto, count: count)
    }
    
    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(year: year, month: month, day: day)
        ) ?? Date()
    }
}
