import Foundation

enum LottoServiceError: Error, LocalizedError {
    case unsupportedGame
    case noData
    
    var errorDescription: String? {
        switch self {
        case .unsupportedGame:
            return "Ta gra nie jest jeszcze obsługiwana."
        case .noData:
            return "Brak danych dla wybranej gry."
        }
    }
}

protocol LottoService {
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult]
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult?
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date]
}

struct MockLottoService: LottoService {
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult] {
        try await simulateNetworkDelay()
        
        guard game.isImplemented else {
            return []
        }
        
        return DrawResult.samples
            .filter { $0.game == game }
            .sorted { $0.drawDate > $1.drawDate }
    }
    
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult? {
        let draws = try await fetchDraws(for: game)
        return draws.first
    }
    
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date] {
        try await simulateNetworkDelay()
        
        guard game.isImplemented else {
            return []
        }
        
        return DrawResult.upcomingDrawDates(for: game, count: count)
    }
    
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
