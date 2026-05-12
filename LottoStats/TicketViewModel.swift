import Foundation
import Combine

@MainActor
final class TicketViewModel: ObservableObject {
    @Published private(set) var tickets: [LottoTicket] = []
    
    @Published var numberInputs = Array(repeating: "", count: 6)
    @Published var includesPlus = false
    @Published var selectedDrawCount = 1
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var ticketToDelete: LottoTicket?
    @Published var showDeleteAlert = false
    
    let game: LottoGame = .lotto
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
    
    var selectedDrawDates: [Date] {
        repository.upcomingDrawDates(
            for: game,
            count: selectedDrawCount
        )
    }
    
    func checkResult(for ticket: LottoTicket) -> TicketCheckResult {
        ticketChecker.check(ticket: ticket)
    }
    
    func generateRandomTicket() {
        let randomNumbers = Array(1...49)
            .shuffled()
            .prefix(6)
            .sorted()
        
        numberInputs = randomNumbers.map { String($0) }
        errorMessage = nil
        successMessage = nil
    }
    
    func saveTicket() {
        let numbers = numberInputs.compactMap { input in
            Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        guard numbers.count == 6 else {
            errorMessage = "Wpisz dokładnie 6 liczb."
            successMessage = nil
            return
        }
        
        guard numbers.allSatisfy({ number in
            number >= 1 && number <= 49
        }) else {
            errorMessage = "Każda liczba musi być z zakresu od 1 do 49."
            successMessage = nil
            return
        }
        
        guard Set(numbers).count == 6 else {
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
            gameName: game.displayName,
            numbers: sortedNumbers,
            drawDate: firstDrawDate,
            drawDates: drawDatesForTicket,
            includesPlus: includesPlus
        )
        
        tickets.insert(newTicket, at: 0)
        saveTickets()
        
        numberInputs = Array(repeating: "", count: 6)
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
