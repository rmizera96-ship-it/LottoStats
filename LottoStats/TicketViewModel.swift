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
    
    @Published var numberInputs: [String] = []
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
    
    var selectedMainNumbers: [Int] {
        numbers(from: numberInputs)
    }
    
    var selectedExtraNumbers: [Int] {
        numbers(from: extraNumberInputs)
    }
    
    var mainSelectionProgressText: String {
        "Wybrano \(selectedMainNumbers.count)/\(currentRules.mainNumbersCount) liczb z zakresu \(currentRules.mainNumberRange.lowerBound)-\(currentRules.mainNumberRange.upperBound)."
    }
    
    var extraSelectionProgressText: String {
        guard let extraRange = currentRules.extraNumberRange else {
            return "Brak dodatkowych liczb dla tej gry."
        }
        
        return "Wybrano \(selectedExtraNumbers.count)/\(currentRules.extraNumbersCount) euroliczb z zakresu \(extraRange.lowerBound)-\(extraRange.upperBound)."
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
    
    var canAddCurrentLine: Bool {
        hasAnyCurrentInput
    }
    
    var canSaveTicket: Bool {
        !draftLines.isEmpty || hasAnyCurrentInput
    }
    
    var draftLinesCountText: String {
        if draftLines.isEmpty {
            return "Brak zestawów"
        }
        
        if draftLines.count == 1 {
            return "1 zestaw"
        }
        
        return "\(draftLines.count) zestawy"
    }
    
    func checkResult(for ticket: LottoTicket) -> TicketCheckResult {
        ticketChecker.check(ticket: ticket)
    }
    
    func isMainNumberSelected(_ number: Int) -> Bool {
        selectedMainNumbers.contains(number)
    }
    
    func isExtraNumberSelected(_ number: Int) -> Bool {
        selectedExtraNumbers.contains(number)
    }
    
    func toggleMainNumber(_ number: Int) {
        var selectedNumbers = selectedMainNumbers
        
        if selectedNumbers.contains(number) {
            selectedNumbers.removeAll { $0 == number }
            numberInputs = selectedNumbers.sorted().map(String.init)
            errorMessage = nil
            successMessage = nil
            return
        }
        
        guard selectedNumbers.count < currentRules.mainNumbersCount else {
            errorMessage = "Możesz wybrać maksymalnie \(currentRules.mainNumbersCount) liczb głównych."
            successMessage = nil
            return
        }
        
        selectedNumbers.append(number)
        numberInputs = selectedNumbers.sorted().map(String.init)
        errorMessage = nil
        successMessage = nil
    }
    
    func toggleExtraNumber(_ number: Int) {
        var selectedNumbers = selectedExtraNumbers
        
        if selectedNumbers.contains(number) {
            selectedNumbers.removeAll { $0 == number }
            extraNumberInputs = selectedNumbers.sorted().map(String.init)
            errorMessage = nil
            successMessage = nil
            return
        }
        
        guard selectedNumbers.count < currentRules.extraNumbersCount else {
            errorMessage = "Możesz wybrać maksymalnie \(currentRules.extraNumbersCount) euroliczby."
            successMessage = nil
            return
        }
        
        selectedNumbers.append(number)
        extraNumberInputs = selectedNumbers.sorted().map(String.init)
        errorMessage = nil
        successMessage = nil
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
    
    func clearCurrentInputs() {
        resetCurrentInputs()
        errorMessage = nil
        successMessage = nil
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
        successMessage = "Kupon z \(linesToSave.count) zestawem/zestawami został zapisany na \(drawCountForMessage) losowanie/losowań."
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
        !selectedMainNumbers.isEmpty || !selectedExtraNumbers.isEmpty
    }
    
    private func makeLineFromCurrentInputs() -> TicketLine? {
        let numbers = selectedMainNumbers
        let extraNumbers = selectedExtraNumbers
        
        guard numbers.count == currentRules.mainNumbersCount else {
            errorMessage = "Wybierz dokładnie \(currentRules.mainNumbersCount) liczb głównych."
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
                errorMessage = "Wybierz dokładnie \(currentRules.extraNumbersCount) euroliczby."
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
        numberInputs = []
        extraNumberInputs = []
    }
    
    private func numbers(from inputs: [String]) -> [Int] {
        inputs
            .compactMap { input in
                Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .sorted()
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
