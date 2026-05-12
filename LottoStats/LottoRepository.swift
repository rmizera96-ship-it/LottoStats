import Foundation

struct LottoRepository {
    static let shared = LottoRepository()
    
    private init() {}
    
    private var allDraws: [DrawResult] {
        DrawResult.samples
    }
    
    func availableGames() -> [LottoGame] {
        LottoGame.allCases
    }
    
    func draws(for game: LottoGame) -> [DrawResult] {
        allDraws
            .filter { $0.game == game }
            .sorted { $0.drawDate > $1.drawDate }
    }
    
    func latestDraw(for game: LottoGame) -> DrawResult? {
        draws(for: game).first
    }
    
    func result(for game: LottoGame, drawDate: Date) -> DrawResult? {
        draws(for: game).first { result in
            Calendar.current.isDate(result.drawDate, inSameDayAs: drawDate)
        }
    }
    
    func result(for gameName: String, drawDate: Date) -> DrawResult? {
        guard let game = LottoGame.fromDisplayName(gameName) else {
            return nil
        }
        
        return result(for: game, drawDate: drawDate)
    }
    
    func upcomingDrawDates(for game: LottoGame, count: Int) -> [Date] {
        DrawResult.upcomingDrawDates(for: game, count: count)
    }
}
