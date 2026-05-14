import Foundation
import Combine

@MainActor
final class LottoDataViewModel: ObservableObject {
    @Published private(set) var selectedGame: LottoGame = .lotto
    @Published private(set) var draws: [DrawResult] = []
    @Published private(set) var latestDraw: DrawResult?
    @Published private(set) var upcomingDrawDates: [Date] = []
    @Published private(set) var gameInfo: LottoGameAPIInfo?
    @Published private(set) var jackpotInfo: LottoJackpotAPIInfo?
    @Published private(set) var highestWins: [LottoHighestWin] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let repository: LottoRepository
    
    var dataSourceName: String {
        repository.dataSourceName
    }
    
    var nextDrawDate: Date? {
        upcomingDrawDates.first ?? gameInfo?.nextDrawDate ?? jackpotInfo?.closestDraw
    }
    
    init() {
        self.repository = LottoRepository.shared
    }
    
    init(repository: LottoRepository) {
        self.repository = repository
    }
    
    func loadInitialData() async {
        if draws.isEmpty && upcomingDrawDates.isEmpty {
            await loadData(for: selectedGame)
        }
    }
    
    func refresh() async {
        await loadData(for: selectedGame)
    }
    
    func selectGame(_ game: LottoGame) async {
        selectedGame = game
        await loadData(for: game)
    }
    
    func loadData(for game: LottoGame) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedDraws = try await repository.fetchDraws(for: game)
            let fetchedUpcomingDrawDates = try await repository.fetchUpcomingDrawDates(
                for: game,
                count: 10
            )
            
            var fetchedGameInfo: LottoGameAPIInfo?
            var fetchedJackpotInfo: LottoJackpotAPIInfo?
            var fetchedHighestWins: [LottoHighestWin] = highestWins
            
            do {
                fetchedGameInfo = try await repository.fetchGameInfo(for: game)
            } catch {
                print("Nie udało się pobrać informacji o grze:", error)
            }
            
            do {
                fetchedJackpotInfo = try await repository.fetchJackpotInfo(for: game)
            } catch {
                print("Nie udało się pobrać kumulacji:", error)
            }
            
            do {
                if highestWins.isEmpty {
                    fetchedHighestWins = try await repository.fetchHighestWins(limit: 10)
                }
            } catch {
                print("Nie udało się pobrać ostatnich wysokich wygranych:", error)
            }
            
            draws = fetchedDraws
            latestDraw = fetchedDraws.first
            upcomingDrawDates = fetchedUpcomingDrawDates
            gameInfo = fetchedGameInfo
            jackpotInfo = fetchedJackpotInfo
            highestWins = fetchedHighestWins
            
            if fetchedDraws.isEmpty {
                errorMessage = "Brak danych dla gry \(game.displayName)."
            }
        } catch {
            draws = []
            latestDraw = nil
            upcomingDrawDates = []
            gameInfo = nil
            jackpotInfo = nil
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
