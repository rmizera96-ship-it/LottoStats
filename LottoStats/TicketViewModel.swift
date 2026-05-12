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
            
            extraNumberInputs = Array(
                repeating: "",
                count: currentRules.extraNumbersCount
            )
            
            selectedDrawCount = 1
            errorMessage = nil
            successMessage = nil
        }
    }
    
    @Published var numberInputs = Array(repeating: "", count: 6)
    @Published var extraNumberInputs: [String] = []
    @Published var includesPlus = false
    @Published var selectedDrawCount = 1
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var ticketToDelete: LottoTicket?
    @Published var showDeleteAlert = false
    
    let drawCountOptions = [1, 2, 4, 8, 10]
    
    private let repository: LottoRepository
    private let ticketChecker: TicketChecker
    
    init() {
        self.repository = LottoRepository.shared
        self.ticketChecker = TicketChecker()
        loadTickets()
    }
    
    init(
        repository: LottoRepository,
        ticketChecker: TicketChecker
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
        let randomNumbers = Array(currentRules.mainNumberRange)
            .shuffled()
            .prefix(currentRules.mainNumbersCount)
            .sorted()
        
        numberInputs = randomNumbers.map { String($0) }
        
        if let extraRange = currentRules.extraNumberRange,
           currentRules.extraNumbersCount > 0 {
            let randomExtraNumbers = Array(extraRange)
                .shuffled()
                .prefix(currentRules.extraNumbersCount)
                .sorted()
            
            extraNumberInputs = randomExtraNumbers.map { String($0) }
        } else {
            extraNumberInputs = []
        }
        
        errorMessage = nil
        successMessage = nil
    }
    
    func saveTicket() {
        let numbers = numberInputs.compactMap { input in
            Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        let extraNumbers = extraNumberInputs.compactMap { input in
            Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        guard numbers.count == currentRules.mainNumbersCount else {
            errorMessage = "Wpisz dokładnie \(currentRules.mainNumbersCount) liczb głównych."
            successMessage = nil
            return
        }
        
        guard numbers.allSatisfy({ number in
            currentRules.mainNumberRange.contains(number)
        }) else {
            errorMessage = "Liczby główne muszą być z zakresu \(currentRules.mainNumberRange.lowerBound)-\(currentRules.mainNumberRange.upperBound)."
            successMessage = nil
            return
        }
        
        guard Set(numbers).count == currentRules.mainNumbersCount else {
            errorMessage = "Liczby główne nie mogą się powtarzać."
            successMessage = nil
            return
        }
        
        if currentRules.extraNumbersCount > 0 {
            guard let extraRange = currentRules.extraNumberRange else {
                errorMessage = "Brak konfiguracji dla dodatkowych liczb."
                successMessage = nil
                return
            }
            
            guard extraNumbers.count == currentRules.extraNumbersCount else {
                errorMessage = "Wpisz dokładnie \(currentRules.extraNumbersCount) euroliczby."
                successMessage = nil
                return
            }
            
            guard extraNumbers.allSatisfy({ number in
                extraRange.contains(number)
            }) else {
                errorMessage = "Euroliczby muszą być z zakresu \(extraRange.lowerBound)-\(extraRange.upperBound)."
                successMessage = nil
                return
            }
            
            guard Set(extraNumbers).count == currentRules.extraNumbersCount else {
                errorMessage = "Euroliczby nie mogą się powtarzać."
                successMessage = nil
                return
            }
        }
        
        guard let firstDrawDate = selectedDrawDates.first else {
            errorMessage = "Nie udało się ustalić daty losowania."
            successMessage = nil
            return
        }
        
        let sortedNumbers = numbers.sorted()
        let sortedExtraNumbers = extraNumbers.sorted()
        let drawDatesForTicket = selectedDrawDates
        let drawCountForMessage = drawDatesForTicket.count
        
        let newTicket = LottoTicket(
            gameName: selectedGame.displayName,
            numbers: sortedNumbers,
            extraNumbers: sortedExtraNumbers,
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
        extraNumberInputs = Array(
            repeating: "",
            count: currentRules.extraNumbersCount
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
