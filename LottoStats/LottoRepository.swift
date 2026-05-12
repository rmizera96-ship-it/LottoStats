import Foundation

struct LottoRepository {
    static let shared = LottoRepository(service: MockLottoService())
    
    private let service: LottoService
    
    init(service: LottoService) {
        self.service = service
    }
    
    private var allDraws: [DrawResult] {
        DrawResult.samples
    }
    
    // MARK: - Local data
    
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
    
    // MARK: - API-ready async data
    
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult] {
        try await service.fetchDraws(for: game)
    }
    
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult? {
        try await service.fetchLatestDraw(for: game)
    }
    
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date] {
        try await service.fetchUpcomingDrawDates(for: game, count: count)
    }
}
