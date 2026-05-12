import Foundation
import Combine

enum TicketStatusFilter: String, CaseIterable, Identifiable {
    case all = "Wszystkie"
    case active = "Aktywne"
    case checked = "Sprawdzone"
    case partiallyChecked = "Częściowo"
    case waitingForResults = "Oczekujące"
    
    var id: String {
        rawValue
    }
    
    var displayName: String {
        rawValue
    }
    
    func matches(_ status: TicketStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .active:
            if case .active = status { return true }
            return false
        case .checked:
            if case .checked = status { return true }
            return false
        case .partiallyChecked:
            if case .partiallyChecked = status { return true }
            return false
        case .waitingForResults:
            if case .waitingForResults = status { return true }
            return false
        }
    }
}

enum TicketGameFilter: String, CaseIterable, Identifiable {
    case all = "Wszystkie"
    case lotto = "Lotto"
    case miniLotto = "Mini Lotto"
    case eurojackpot = "Eurojackpot"
    
    var id: String {
        rawValue
    }
    
    var displayName: String {
        rawValue
    }
    
    var game: LottoGame? {
        switch self {
        case .all:
            return nil
        case .lotto:
            return .lotto
        case .miniLotto:
            return .miniLotto
        case .eurojackpot:
            return .eurojackpot
        }
    }
}

@MainActor
final class TicketViewModel: ObservableObject {
    @Published private(set) var tickets: [LottoTicket] = []
    
    @Published var selectedGame: LottoGame = .lotto {
        didSet {
            if !currentRules.supportsPlus {
                includesPlus = false
            }
            
            resetCurrentInputs()
            draftLines.removeAll()
            selectedDrawCount = 1
            errorMessage = nil
            successMessage = nil
        }
    }
    
    @Published var selectedStatusFilter: TicketStatusFilter = .all
    @Published var selectedGameFilter: TicketGameFilter = .all
    
    @Published var numberInputs = Array(repeating: "", count: 6)
    @Published var extraNumberInputs: [String] = []
    @Published var draftLines: [TicketLine] = []
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
    
    var filteredTickets: [LottoTicket] {
        tickets.filter { ticket in
            let matchesGame: Bool
            
            if let selectedGame = selectedGameFilter.game {
                matchesGame = ticket.game == selectedGame
            } else {
                matchesGame = true
            }
            
            let status = checkResult(for: ticket).status
            let matchesStatus = selectedStatusFilter.matches(status)
            
            return matchesGame && matchesStatus
        }
    }
    
    var filteredTicketsCount: Int {
        filteredTickets.count
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
    
    func addCurrentLineToDraft() {
        guard let line = makeLineFromCurrentInputs() else {
            return
        }
        
        draftLines.append(line)
        resetCurrentInputs()
        errorMessage = nil
        successMessage = "Dodano zestaw \(draftLines.count) do kuponu."
    }
    
    func removeDraftLine(_ line: TicketLine) {
        draftLines.removeAll { $0.id == line.id }
    }
    
    func clearDraftLines() {
        draftLines.removeAll()
        successMessage = nil
        errorMessage = nil
    }
    
    func saveTicket() {
        var linesToSave = draftLines
        
        if hasAnyCurrentInput {
            guard let currentLine = makeLineFromCurrentInputs() else {
                return
            }
            
            linesToSave.append(currentLine)
        }
        
        guard !linesToSave.isEmpty else {
            errorMessage = "Dodaj co najmniej jeden zestaw liczb do kuponu."
            successMessage = nil
            return
        }
        
        guard let firstDrawDate = selectedDrawDates.first else {
            errorMessage = "Nie udało się ustalić daty losowania."
            successMessage = nil
            return
        }
        
        let drawDatesForTicket = selectedDrawDates
        let drawCountForMessage = drawDatesForTicket.count
        
        let newTicket = LottoTicket(
            gameName: selectedGame.displayName,
            lines: linesToSave,
            drawDate: firstDrawDate,
            drawDates: drawDatesForTicket,
            includesPlus: currentRules.supportsPlus ? includesPlus : false
        )
        
        tickets.insert(newTicket, at: 0)
        saveTickets()
        
        draftLines.removeAll()
        resetCurrentInputs()
        includesPlus = false
        selectedDrawCount = 1
        selectedGameFilter = .all
        selectedStatusFilter = .all
        errorMessage = nil
        successMessage = "Kupon z \(linesToSave.count) zestawem/zestawami został zapisany."
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
        
        selectedStatusFilter = .all
        selectedGameFilter = .all
        errorMessage = nil
        successMessage = "Wszystkie kupony zostały usunięte."
    }
    
    private var hasAnyCurrentInput: Bool {
        let hasMainInput = numberInputs.contains { input in
            !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        let hasExtraInput = extraNumberInputs.contains { input in
            !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return hasMainInput || hasExtraInput
    }
    
    private func makeLineFromCurrentInputs() -> TicketLine? {
        let numbers = numberInputs.compactMap { input in
            Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        let extraNumbers = extraNumberInputs.compactMap { input in
            Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        guard numbers.count == currentRules.mainNumbersCount else {
            errorMessage = "Wpisz dokładnie \(currentRules.mainNumbersCount) liczb głównych."
            successMessage = nil
            return nil
        }
        
        guard numbers.allSatisfy({ number in
            currentRules.mainNumberRange.contains(number)
        }) else {
            errorMessage = "Liczby główne muszą być z zakresu \(currentRules.mainNumberRange.lowerBound)-\(currentRules.mainNumberRange.upperBound)."
            successMessage = nil
            return nil
        }
        
        guard Set(numbers).count == currentRules.mainNumbersCount else {
            errorMessage = "Liczby główne nie mogą się powtarzać."
            successMessage = nil
            return nil
        }
        
        if currentRules.extraNumbersCount > 0 {
            guard let extraRange = currentRules.extraNumberRange else {
                errorMessage = "Brak konfiguracji dla dodatkowych liczb."
                successMessage = nil
                return nil
            }
            
            guard extraNumbers.count == currentRules.extraNumbersCount else {
                errorMessage = "Wpisz dokładnie \(currentRules.extraNumbersCount) euroliczby."
                successMessage = nil
                return nil
            }
            
            guard extraNumbers.allSatisfy({ number in
                extraRange.contains(number)
            }) else {
                errorMessage = "Euroliczby muszą być z zakresu \(extraRange.lowerBound)-\(extraRange.upperBound)."
                successMessage = nil
                return nil
            }
            
            guard Set(extraNumbers).count == currentRules.extraNumbersCount else {
                errorMessage = "Euroliczby nie mogą się powtarzać."
                successMessage = nil
                return nil
            }
        }
        
        return TicketLine(
            numbers: numbers.sorted(),
            extraNumbers: extraNumbers.sorted()
        )
    }
    
    private func resetCurrentInputs() {
        numberInputs = Array(
            repeating: "",
            count: currentRules.mainNumbersCount
        )
        
        extraNumberInputs = Array(
            repeating: "",
            count: currentRules.extraNumbersCount
        )
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
