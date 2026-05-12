import Foundation
import Combine

@MainActor
final class TicketViewModel: ObservableObject {
    @Published private(set) var tickets: [LottoTicket] = []
    
    @Published var selectedGame: LottoGame = .lotto {
        didSet {
            if !currentRules.supportsPlus {
                includesPlus = false
            }
            
            numberInputs = Array(
                repeating: "",
                count: currentRules.mainNumbersCount
            )
            
            selectedDrawCount = 1
            errorMessage = nil
            successMessage = nil
        }
    }
    
    @Published var numberInputs = Array(repeating: "", count: 6)
    @Published var includesPlus = false
    @Published var selectedDrawCount = 1
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var ticketToDelete: LottoTicket?
    @Published var showDeleteAlert = false
    
    let drawCountOptions = [1, 2, 4, 8, 10]
    
    private let repository: LottoRepository
    private let ticketChecker: TicketChecker
    
    init(
        repository: LottoRepository = .shared,
        ticketChecker: TicketChecker = TicketChecker()
    ) {
        self.repository = repository
        self.ticketChecker = ticketChecker
        loadTickets()
    }
    
    var availableGamesForTickets: [LottoGame] {
        LottoGame.allCases
    }
    
    var currentRules: GameRules {
        GameRules.rules(for: selectedGame)
    }
    
    var selectedDrawDates: [Date] {
        repository.upcomingDrawDates(
            for: selectedGame,
            count: selectedDrawCount
        )
    }
    
    func checkResult(for ticket: LottoTicket) -> TicketCheckResult {
        ticketChecker.check(ticket: ticket)
    }
    
    func generateRandomTicket() {
        guard currentRules.supportsTicketsInCurrentVersion else {
            errorMessage = "Gra \(selectedGame.displayName) wymaga dodatkowych liczb i zostanie dodana później."
            successMessage = nil
            return
        }
        
        let randomNumbers = Array(currentRules.mainNumberRange)
            .shuffled()
            .prefix(currentRules.mainNumbersCount)
            .sorted()
        
        numberInputs = randomNumbers.map { String($0) }
        errorMessage = nil
        successMessage = nil
    }
    
    func saveTicket() {
        guard currentRules.supportsTicketsInCurrentVersion else {
            errorMessage = "Dodawanie kuponów dla gry \(selectedGame.displayName) dodamy w kolejnym etapie."
            successMessage = nil
            return
        }
        
        let numbers = numberInputs.compactMap { input in
            Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        guard numbers.count == currentRules.mainNumbersCount else {
            errorMessage = "Wpisz dokładnie \(currentRules.mainNumbersCount) liczb."
            successMessage = nil
            return
        }
        
        guard numbers.allSatisfy({ number in
            currentRules.mainNumberRange.contains(number)
        }) else {
            errorMessage = "Każda liczba musi być z zakresu \(currentRules.mainNumberRange.lowerBound)-\(currentRules.mainNumberRange.upperBound)."
            successMessage = nil
            return
        }
        
        guard Set(numbers).count == currentRules.mainNumbersCount else {
            errorMessage = "Liczby nie mogą się powtarzać."
            successMessage = nil
            return
        }
        
        guard let firstDrawDate = selectedDrawDates.first else {
            errorMessage = "Nie udało się ustalić daty losowania."
            successMessage = nil
            return
        }
        
        let sortedNumbers = numbers.sorted()
        let drawDatesForTicket = selectedDrawDates
        let drawCountForMessage = drawDatesForTicket.count
        
        let newTicket = LottoTicket(
            gameName: selectedGame.displayName,
            numbers: sortedNumbers,
            drawDate: firstDrawDate,
            drawDates: drawDatesForTicket,
            includesPlus: currentRules.supportsPlus ? includesPlus : false
        )
        
        tickets.insert(newTicket, at: 0)
        saveTickets()
        
        numberInputs = Array(
            repeating: "",
            count: currentRules.mainNumbersCount
        )
        includesPlus = false
        selectedDrawCount = 1
        errorMessage = nil
        successMessage = "Kupon został dodany na \(drawCountForMessage) losowanie/losowań."
    }
    
    func requestDelete(_ ticket: LottoTicket) {
        ticketToDelete = ticket
        showDeleteAlert = true
    }
    
    func cancelDelete() {
        ticketToDelete = nil
        showDeleteAlert = false
    }
    
    func confirmDelete() {
        guard let ticketToDelete else {
            return
        }
        
        deleteTicket(ticketToDelete)
    }
    
    func clearAllTickets() {
        tickets.removeAll()
        saveTickets()
        
        errorMessage = nil
        successMessage = "Wszystkie kupony zostały usunięte."
    }
    
    private func deleteTicket(_ ticket: LottoTicket) {
        tickets.removeAll { $0.id == ticket.id }
        saveTickets()
        
        ticketToDelete = nil
        showDeleteAlert = false
        errorMessage = nil
        successMessage = "Kupon został usunięty."
    }
    
    private func loadTickets() {
        tickets = TicketStorage.load()
    }
    
    private func saveTickets() {
        TicketStorage.save(tickets)
    }
}
