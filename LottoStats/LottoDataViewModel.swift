import Foundation
import Combine

enum LottoDataLoadMode {
    case dashboard
    case history
}

@MainActor
final class LottoDataViewModel: ObservableObject {
    @Published private(set) var selectedGame: LottoGame = .lotto
    @Published private(set) var draws: [DrawResult] = []
    @Published private(set) var latestDraw: DrawResult?
    @Published private(set) var upcomingDrawDates: [Date] = []
    @Published private(set) var upcomingDrawDatesByGame: [LottoGame: Date] = [:]
    @Published private(set) var gameInfo: LottoGameAPIInfo?
    @Published private(set) var jackpotInfo: LottoJackpotAPIInfo?
    @Published private(set) var highestWins: [LottoHighestWin] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    
    private let repository: LottoRepository
    private let loadMode: LottoDataLoadMode
    
    var dataSourceName: String {
        repository.dataSourceName
    }
    
    var nextDrawDate: Date? {
        upcomingDrawDates.first ?? gameInfo?.nextDrawDate ?? jackpotInfo?.closestDraw
    }
    
    init(mode: LottoDataLoadMode = .dashboard) {
        self.repository = LottoRepository.shared
        self.loadMode = mode
    }
    
    init(
        repository: LottoRepository,
        mode: LottoDataLoadMode = .dashboard
    ) {
        self.repository = repository
        self.loadMode = mode
    }
    
    func loadInitialData() async {
        guard !isLoading else {
            return
        }
        
        switch loadMode {
        case .dashboard:
            if latestDraw == nil && upcomingDrawDates.isEmpty {
                await loadData(for: selectedGame)
            }
        case .history:
            if draws.isEmpty {
                await loadData(for: selectedGame)
            }
        }
    }
    
    func refresh() async {
        repository.invalidateAPICache()
        await loadData(for: selectedGame)
    }
    
    func loadUpcomingDrawDatesForAllGames(forceRefresh: Bool = false) async {
        if forceRefresh {
            repository.invalidateAPICache()
            upcomingDrawDatesByGame.removeAll()
        }
        
        var updatedDates = upcomingDrawDatesByGame
        
        for game in LottoGame.allCases where updatedDates[game] == nil {
            do {
                if let date = try await repository.fetchUpcomingDrawDates(
                    for: game,
                    count: 1
                ).first {
                    updatedDates[game] = date
                }
            } catch {
                AppLogger.debug("Nie udało się pobrać najbliższego losowania dla", game.displayName, error)
            }
        }
        
        upcomingDrawDatesByGame = updatedDates
    }
    
    func selectGame(_ game: LottoGame) async {
        guard game != selectedGame || latestDraw == nil else {
            return
        }

        let gameChanged = game != selectedGame
        selectedGame = game

        if gameChanged {
            draws = []
            latestDraw = nil
            upcomingDrawDates = []
            gameInfo = nil
            jackpotInfo = nil
            errorMessage = nil
        }

        await loadData(for: game)
    }
    
    func loadData(for game: LottoGame) async {
        guard !isLoading else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        switch loadMode {
        case .dashboard:
            await loadDashboardData(for: game)
        case .history:
            await loadHistoryData(for: game)
        }
        
        isLoading = false

        if selectedGame != game {
            await loadData(for: selectedGame)
        }
    }
    
    private func loadDashboardData(for game: LottoGame) async {
        async let latestRequest: DrawResult? = try? repository.fetchLatestDraw(for: game)
        async let upcomingRequest: [Date]? = try? repository.fetchUpcomingDrawDates(
            for: game,
            count: 10
        )
        async let gameInfoRequest: LottoGameAPIInfo? = try? repository.fetchGameInfo(for: game)
        async let jackpotRequest: LottoJackpotAPIInfo? = try? repository.fetchJackpotInfo(for: game)
        async let highestWinsRequest: [LottoHighestWin]? = try? repository.fetchHighestWins(limit: 10)
        
        let fetchedLatest = await latestRequest
        let fetchedUpcoming = await upcomingRequest ?? []
        let fetchedGameInfo = await gameInfoRequest
        let fetchedJackpotInfo = await jackpotRequest
        let fetchedHighestWins = await highestWinsRequest ?? highestWins

        guard selectedGame == game else {
            return
        }
        
        if let fetchedLatest {
            latestDraw = fetchedLatest
            draws = [fetchedLatest]
        }

        if !fetchedUpcoming.isEmpty {
            upcomingDrawDates = fetchedUpcoming
        }

        gameInfo = fetchedGameInfo ?? gameInfo
        jackpotInfo = fetchedJackpotInfo ?? jackpotInfo
        highestWins = fetchedHighestWins
        
        if let nextDate = fetchedUpcoming.first {
            upcomingDrawDatesByGame[game] = nextDate
        }
        
        if fetchedLatest == nil,
           fetchedUpcoming.isEmpty,
           fetchedGameInfo == nil,
           fetchedJackpotInfo == nil {
            errorMessage = "Nie udało się pobrać danych dla gry \(game.displayName)."
        } else {
            lastUpdated = Date()
        }
    }
    
    private func loadHistoryData(for game: LottoGame) async {
        do {
            let fetchedDraws = try await repository.fetchDraws(for: game)

            guard selectedGame == game else {
                return
            }

            draws = fetchedDraws
            latestDraw = fetchedDraws.first
            
            if fetchedDraws.isEmpty {
                errorMessage = "Brak danych dla gry \(game.displayName)."
            } else {
                lastUpdated = Date()
            }
        } catch {
            guard selectedGame == game else {
                return
            }

            if draws.first?.game != game {
                draws = []
                latestDraw = nil
            }

            errorMessage = error.localizedDescription
        }
    }
}
