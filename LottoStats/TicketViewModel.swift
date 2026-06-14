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
    
    @Published private(set) var isLoadingTicketResults = false
    @Published private(set) var ticketResultsSourceName = "Lokalne dane"
    @Published private(set) var ticketResultsErrorMessage: String?
    
    @Published private(set) var isLoadingDrawDates = false
    @Published private(set) var drawDatesSourceName = "API LOTTO"
    @Published private(set) var drawDatesErrorMessage: String?

    @Published private(set) var isLoadingTicketPrizes = false
    @Published private(set) var ticketPrizesErrorMessage: String?
    
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
    private let ticketPrizeCalculator = TicketPrizeCalculator()
    
    private var cachedDrawResultsByGame: [LottoGame: [DrawResult]] = [:]
    private var cachedUpcomingDrawDatesByGame: [LottoGame: [Date]] = [:]
    private var drawDatesLastRefreshByGame: [LottoGame: Date] = [:]
    private var lastTicketResultsRefresh: Date?
    private var prizeInfoByDrawKey: [String: [LottoDrawPrizeInfo]] = [:]
    private var loadedPrizeDrawKeys: Set<String> = []
    
    private let automaticRefreshInterval: TimeInterval = 30 * 60
    
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
        let dates = cachedUpcomingDrawDatesByGame[selectedGame] ?? []
        return Array(dates.prefix(selectedDrawCount))
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

    var checkedTicketsCount: Int {
        tickets.filter { ticket in
            if case .checked = checkResult(for: ticket).status {
                return true
            }

            return false
        }.count
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
    
    func selectGame(_ game: LottoGame) async {
        selectedGame = game
        await refreshUpcomingDrawDates(for: game)
    }
    
    func refreshUpcomingDrawDates(
        for game: LottoGame? = nil,
        forceRefresh: Bool = false
    ) async {
        let targetGame = game ?? selectedGame
        
        if !forceRefresh,
           let cachedDates = cachedUpcomingDrawDatesByGame[targetGame],
           !cachedDates.isEmpty,
           let lastRefresh = drawDatesLastRefreshByGame[targetGame],
           Date().timeIntervalSince(lastRefresh) < automaticRefreshInterval {
            return
        }
        
        if forceRefresh {
            repository.invalidateAPICache()
            cachedUpcomingDrawDatesByGame[targetGame] = nil
        }
        
        isLoadingDrawDates = true
        drawDatesErrorMessage = nil
        
        do {
            let apiDates = try await repository.fetchUpcomingDrawDates(
                for: targetGame,
                count: 1
            )
            
            guard let nextDrawDate = apiDates.first else {
                cachedUpcomingDrawDatesByGame[targetGame] = []
                drawDatesSourceName = repository.dataSourceName
                drawDatesErrorMessage = "API nie zwróciło daty najbliższego losowania."
                drawDatesLastRefreshByGame[targetGame] = Date()
                isLoadingDrawDates = false
                return
            }
            
            let generatedDates = generateUpcomingDrawDates(
                from: nextDrawDate,
                for: targetGame,
                count: 10
            )
            
            cachedUpcomingDrawDatesByGame[targetGame] = generatedDates
            drawDatesSourceName = repository.dataSourceName
        } catch {
            AppLogger.debug("Nie udało się pobrać dat losowań dla", targetGame.displayName, error)
            
            cachedUpcomingDrawDatesByGame[targetGame] = []
            drawDatesSourceName = repository.dataSourceName
            drawDatesErrorMessage = "Nie udało się pobrać dat losowań z API. Spróbuj odświeżyć."
        }
        
        drawDatesLastRefreshByGame[targetGame] = Date()
        isLoadingDrawDates = false
    }
    
    func checkResult(for ticket: LottoTicket) -> TicketCheckResult {
        let drawResults = cachedDrawResultsByGame[ticket.game] ?? repository.draws(for: ticket.game)
        
        return ticketChecker.check(
            ticket: ticket,
            drawResults: drawResults
        )
    }

    func winningsSummary(for ticket: LottoTicket) -> TicketWinningsSummary {
        ticketPrizeCalculator.calculate(
            ticket: ticket,
            checkResult: checkResult(for: ticket),
            prizeInfoByDrawKey: prizeInfoByDrawKey,
            loadedDrawKeys: loadedPrizeDrawKeys
        )
    }
    
    func refreshTicketResults(
        forceRefresh: Bool = false,
        includePrizes: Bool = false
    ) async {
        if isLoadingTicketResults {
            while isLoadingTicketResults {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            if includePrizes {
                await refreshTicketPrizes(forceRefresh: forceRefresh)
            }
            return
        }
        
        if !forceRefresh,
           let lastRefresh = lastTicketResultsRefresh,
           Date().timeIntervalSince(lastRefresh) < automaticRefreshInterval {
            if includePrizes {
                await refreshTicketPrizes()
            }
            return
        }
        
        if forceRefresh {
            repository.invalidateAPICache()
            cachedDrawResultsByGame.removeAll()
        }
        
        isLoadingTicketResults = true
        ticketResultsErrorMessage = nil
        
        let today = Calendar.current.startOfDay(for: Date())
        
        let gamesToRefresh = availableGamesForTickets.filter { game in
            tickets.contains { ticket in
                ticket.game == game &&
                ticket.drawDates.contains { drawDate in
                    Calendar.current.startOfDay(for: drawDate) <= today
                }
            }
        }
        
        guard !gamesToRefresh.isEmpty else {
            ticketResultsSourceName = "Brak kuponów do sprawdzenia"
            lastTicketResultsRefresh = Date()
            isLoadingTicketResults = false
            if includePrizes {
                await refreshTicketPrizes()
            }
            return
        }
        
        var updatedCache = cachedDrawResultsByGame
        var failedGames: [String] = []
        
        for game in gamesToRefresh {
            do {
                let draws = try await repository.fetchDraws(for: game)
                updatedCache[game] = draws
            } catch {
                AppLogger.debug("Nie udało się pobrać wyników dla", game.displayName, error)
                
                failedGames.append(game.displayName)
                
                if updatedCache[game] == nil {
                    updatedCache[game] = repository.draws(for: game)
                }
            }
        }
        
        cachedDrawResultsByGame = updatedCache
        ticketResultsSourceName = repository.dataSourceName
        
        if !failedGames.isEmpty {
            ticketResultsErrorMessage = "Nie udało się pobrać wyników dla: \(failedGames.joined(separator: ", ")). Te kupony mogą używać danych lokalnych."
        }
        
        lastTicketResultsRefresh = Date()
        isLoadingTicketResults = false

        if includePrizes {
            await refreshTicketPrizes(forceRefresh: forceRefresh)
        }
    }

    func refreshTicketPrizes(
        for singleTicket: LottoTicket? = nil,
        forceRefresh: Bool = false
    ) async {
        if isLoadingTicketPrizes {
            return
        }

        let ticketsToCheck = singleTicket.map { [$0] } ?? tickets
        let drawsToLoad = uniqueDrawsNeededForPrizes(from: ticketsToCheck)

        guard !drawsToLoad.isEmpty else {
            return
        }

        isLoadingTicketPrizes = true
        ticketPrizesErrorMessage = nil

        var updatedPrizeInfo = prizeInfoByDrawKey
        var updatedLoadedKeys = loadedPrizeDrawKeys
        var failedDraws = 0

        for draw in drawsToLoad {
            let key = TicketPrizeCalculator.drawKey(
                game: draw.game,
                drawSystemId: draw.drawSystemId,
                drawDate: draw.drawDate
            )

            if !forceRefresh && updatedLoadedKeys.contains(key) {
                continue
            }

            do {
                let prizeInfo = try await repository.fetchDrawPrizes(for: draw)

                guard !prizeInfo.isEmpty else {
                    failedDraws += 1
                    continue
                }

                updatedPrizeInfo[key] = prizeInfo
                updatedLoadedKeys.insert(key)
            } catch {
                AppLogger.debug(
                    "Nie udało się pobrać wygranych dla",
                    draw.game.displayName,
                    draw.drawDate,
                    error
                )
                failedDraws += 1
            }
        }

        prizeInfoByDrawKey = updatedPrizeInfo
        loadedPrizeDrawKeys = updatedLoadedKeys

        if failedDraws > 0 {
            ticketPrizesErrorMessage = "Nie udało się pobrać kwot wygranych dla części losowań. Spróbuj odświeżyć kupony."
        }

        isLoadingTicketPrizes = false
    }

    func clearCachedAPIData() {
        LottoAPICache.shared.clear()
        cachedDrawResultsByGame.removeAll()
        cachedUpcomingDrawDatesByGame.removeAll()
        drawDatesLastRefreshByGame.removeAll()
        prizeInfoByDrawKey.removeAll()
        loadedPrizeDrawKeys.removeAll()
        lastTicketResultsRefresh = nil
        ticketResultsErrorMessage = nil
        ticketPrizesErrorMessage = nil
        successMessage = "Pamięć podręczna została wyczyszczona. Dane zostaną pobrane przy kolejnym odświeżeniu."
    }

    private func uniqueDrawsNeededForPrizes(
        from tickets: [LottoTicket]
    ) -> [DrawResult] {
        var drawsByKey: [String: DrawResult] = [:]

        for ticket in tickets {
            let drawResults = cachedDrawResultsByGame[ticket.game] ?? repository.draws(for: ticket.game)

            for drawDate in ticket.drawDates {
                guard let draw = drawResults.first(where: {
                    Calendar.current.isDate($0.drawDate, inSameDayAs: drawDate)
                }), draw.drawSystemId != nil else {
                    continue
                }

                let key = TicketPrizeCalculator.drawKey(
                    game: draw.game,
                    drawSystemId: draw.drawSystemId,
                    drawDate: draw.drawDate
                )
                drawsByKey[key] = draw
            }
        }

        return drawsByKey.values.sorted { $0.drawDate > $1.drawDate }
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
        
        guard !selectedDrawDates.isEmpty else {
            errorMessage = "Brak dat losowań z API. Odśwież daty losowań i spróbuj ponownie."
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
    
    func clearCheckedTickets() {
        let checkedTicketIDs = Set(
            tickets.compactMap { ticket -> UUID? in
                if case .checked = checkResult(for: ticket).status {
                    return ticket.id
                }

                return nil
            }
        )

        guard !checkedTicketIDs.isEmpty else {
            errorMessage = nil
            successMessage = "Brak sprawdzonych kuponów do usunięcia."
            return
        }

        let removedCount = checkedTicketIDs.count
        tickets.removeAll { checkedTicketIDs.contains($0.id) }
        saveTickets()

        selectedStatusFilter = .all
        selectedGameFilter = .all
        errorMessage = nil
        successMessage = removedCount == 1
            ? "Usunięto 1 sprawdzony kupon."
            : "Usunięto \(removedCount) sprawdzonych kuponów."
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
    
    private func generateUpcomingDrawDates(
        from nextDrawDate: Date,
        for game: LottoGame,
        count: Int
    ) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        
        let drawTime = calendar.dateComponents(
            [.hour, .minute, .second],
            from: nextDrawDate
        )
        
        var currentDay = calendar.startOfDay(for: nextDrawDate)
        var dates: [Date] = []
        
        while dates.count < count {
            if isDrawDay(currentDay, for: game, calendar: calendar) {
                var components = calendar.dateComponents(
                    [.year, .month, .day],
                    from: currentDay
                )
                
                components.hour = drawTime.hour ?? 22
                components.minute = drawTime.minute ?? 0
                components.second = drawTime.second ?? 0
                
                if let date = calendar.date(from: components),
                   date >= nextDrawDate.addingTimeInterval(-60) {
                    dates.append(date)
                }
            }
            
            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: currentDay
            ) else {
                break
            }
            
            currentDay = nextDay
        }
        
        return dates
    }
    
    private func isDrawDay(
        _ date: Date,
        for game: LottoGame,
        calendar: Calendar
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        
        switch game {
        case .lotto:
            return [3, 5, 7].contains(weekday) // wtorek, czwartek, sobota
        case .miniLotto:
            return true // codziennie
        case .eurojackpot:
            return [3, 6].contains(weekday) // wtorek, piątek
        }
    }
}
