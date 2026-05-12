import Foundation
import Combine

@MainActor
final class LottoDataViewModel: ObservableObject {
    @Published private(set) var selectedGame: LottoGame = .lotto
    @Published private(set) var draws: [DrawResult] = []
    @Published private(set) var latestDraw: DrawResult?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let repository: LottoRepository
    
    init() {
        self.repository = LottoRepository.shared
    }
    
    init(repository: LottoRepository) {
        self.repository = repository
    }
    
    func loadInitialData() async {
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
            draws = fetchedDraws
            latestDraw = fetchedDraws.first
            
            if fetchedDraws.isEmpty {
                errorMessage = "Brak danych dla gry \(game.displayName)."
            }
        } catch {
            draws = []
            latestDraw = nil
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
