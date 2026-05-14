import SwiftUI

struct ContentView: View {
    @StateObject private var ticketViewModel = TicketViewModel()
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeView(tickets: ticketViewModel.tickets)
            }
            .tabItem {
                Label("Start", systemImage: "house.fill")
            }
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Historia", systemImage: "clock.arrow.circlepath")
            }
            
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statystyki", systemImage: "chart.bar.xaxis")
            }
            
            NavigationStack {
                MyTicketsView(viewModel: ticketViewModel)
            }
            .tabItem {
                Label("Kupony", systemImage: "ticket.fill")
            }
            
            NavigationStack {
                SettingsView(ticketViewModel: ticketViewModel)
            }
            .tabItem {
                Label("Ustawienia", systemImage: "gearshape.fill")
            }
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = LottoDataViewModel()
    
    let tickets: [LottoTicket]
    
    private let repository = LottoRepository.shared
    private let ticketChecker = TicketChecker()
    private let bestResultCalculator = BestResultCalculator()
    
    private var games: [LottoGame] {
        repository.availableGames()
    }
    
    private var selectedGameBinding: Binding<LottoGame> {
        Binding {
            viewModel.selectedGame
        } set: { game in
            Task {
                await viewModel.selectGame(game)
            }
        }
    }
    
    private var totalTicketsCount: Int {
        tickets.count
    }
    
    private var totalLinesCount: Int {
        tickets.reduce(0) { partialResult, ticket in
            partialResult + ticket.lines.count
        }
    }
    
    private var activeTicketsCount: Int {
        tickets.filter { ticket in
            let status = ticketChecker.check(ticket: ticket).status
            
            if case .active = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var checkedTicketsCount: Int {
        tickets.filter { ticket in
            let status = ticketChecker.check(ticket: ticket).status
            
            if case .checked = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var partiallyCheckedTicketsCount: Int {
        tickets.filter { ticket in
            let status = ticketChecker.check(ticket: ticket).status
            
            if case .partiallyChecked = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var waitingTicketsCount: Int {
        tickets.filter { ticket in
            let status = ticketChecker.check(ticket: ticket).status
            
            if case .waitingForResults = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var selectedGameActiveTicketsCount: Int {
        tickets.filter { ticket in
            guard ticket.game == viewModel.selectedGame else {
                return false
            }
            
            let status = ticketChecker.check(ticket: ticket).status
            
            if case .active = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var selectedGameLinesCount: Int {
        tickets
            .filter { $0.game == viewModel.selectedGame }
            .reduce(0) { partialResult, ticket in
                partialResult + ticket.lines.count
            }
    }
    
    private var selectedGameTicketsCount: Int {
        tickets.filter { $0.game == viewModel.selectedGame }.count
    }
    
    private var nextDrawRelativeText: String {
        guard let nextDrawDate = viewModel.nextDrawDate else {
            return "Brak danych"
        }
        
        return relativeText(for: nextDrawDate)
    }
    
    private var upcomingDrawItems: [UpcomingDrawItem] {
        games.compactMap { game in
            guard let date = repository.upcomingDrawDates(for: game, count: 1).first else {
                return nil
            }
            
            return UpcomingDrawItem(
                game: game,
                date: date
            )
        }
        .sorted { $0.date < $1.date }
    }
    
    private var todayTickets: [LottoTicket] {
        let today = Calendar.current.startOfDay(for: Date())
        
        return tickets.filter { ticket in
            ticket.drawDates.contains { drawDate in
                Calendar.current.isDate(
                    Calendar.current.startOfDay(for: drawDate),
                    inSameDayAs: today
                )
            }
        }
    }
    
    private var todayTicketsLinesCount: Int {
        todayTickets.reduce(0) { partialResult, ticket in
            partialResult + ticket.lines.count
        }
    }
    
    private var todayTicketsTitle: String {
        if todayTickets.isEmpty {
            return "Brak kuponów na dzisiaj"
        }
        
        if todayTickets.count == 1 {
            return "Masz 1 kupon na dzisiaj"
        }
        
        return "Masz \(todayTickets.count) kuponów na dzisiaj"
    }
    
    private var bestResult: UserBestResult? {
        bestResultCalculator.calculate(from: tickets)
    }
    
    private var bestHitTitleText: String {
        guard let bestResult else {
            return "-"
        }
        
        if let extraHits = bestResult.extraHits {
            if extraHits > 0 {
                return "\(hitName(for: bestResult.mainHits)) + \(extraHits) euro"
            } else {
                return hitName(for: bestResult.mainHits)
            }
        }
        
        return hitName(for: bestResult.mainHits)
    }
    
    private var bestHitSubtitleText: String {
        guard let bestResult else {
            return "Brak sprawdzonych kuponów"
        }
        
        return "\(bestResult.gameName), zestaw \(bestResult.lineIndex + 1)"
    }
    
    private var gameSummaries: [GameTicketSummary] {
        games.map { game in
            let gameTickets = tickets.filter { $0.game == game }
            let linesCount = gameTickets.reduce(0) { partialResult, ticket in
                partialResult + ticket.lines.count
            }
            
            let activeCount = gameTickets.filter { ticket in
                let status = ticketChecker.check(ticket: ticket).status
                
                if case .active = status {
                    return true
                }
                
                return false
            }.count
            
            return GameTicketSummary(
                game: game,
                ticketsCount: gameTickets.count,
                linesCount: linesCount,
                activeTicketsCount: activeCount
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
                Picker("Gra", selection: selectedGameBinding) {
                    ForEach(games) { game in
                        Text(game.displayName)
                            .tag(game)
                    }
                }
                .pickerStyle(.segmented)
                
                latestDrawCard
                
                nextDrawCard
                
                gameInfoCard
                
                recentHighWinsCard
                
                todayTicketsCard
                
                bestResultCard
                
                myTicketsSummaryCard
                
                gameSummaryCard
                
                upcomingDrawsCard
                
                dataSourceSection
                
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Odśwież dane")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("LottoStats")
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LottoStats")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Wyniki losowań, statystyki liczb i Twoje kupony w jednym miejscu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var latestDrawCard: some View {
        AppCard {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    
                    Text("Ładowanie danych...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let latestDraw = viewModel.latestDraw {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ostatnie losowanie")
                                .font(.headline)
                            
                            Text(latestDraw.gameName)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Text(latestDraw.drawDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Liczby główne")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            ForEach(latestDraw.numbers, id: \.self) { number in
                                NumberBall(number: number, style: .lotto)
                            }
                        }
                    }
                    
                    if let extraNumbers = latestDraw.extraNumbers,
                       !extraNumbers.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Euroliczby")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                ForEach(extraNumbers, id: \.self) { number in
                                    NumberBall(number: number, style: .plus)
                                }
                            }
                        }
                    }
                    
                    if let plusNumbers = latestDraw.plusNumbers,
                       viewModel.selectedGame.supportsPlus {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lotto Plus")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                ForEach(plusNumbers, id: \.self) { number in
                                    NumberBall(number: number, style: .plus)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        MetricTile(
                            title: "Najwyższe trafienie",
                            value: bestHitTitleText,
                            subtitle: bestHitSubtitleText
                        )
                        
                        Spacer()
                        
                        MetricTile(
                            title: "Twoje kupony",
                            value: "\(selectedGameTicketsCount)",
                            subtitle: "Dla tej gry"
                        )
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brak danych")
                        .font(.headline)
                    
                    Text(viewModel.errorMessage ?? "Nie udało się pobrać danych.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var nextDrawCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Najbliższe losowanie")
                            .font(.headline)
                        
                        Text(viewModel.selectedGame.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    Text(nextDrawRelativeText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(relativeBackground(for: viewModel.nextDrawDate))
                        .clipShape(Capsule())
                }
                
                if let nextDrawDate = viewModel.nextDrawDate {
                    Text(nextDrawDate.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Brak dostępnej daty najbliższego losowania.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                HStack {
                    MetricTile(
                        title: "Aktywne kupony",
                        value: "\(selectedGameActiveTicketsCount)",
                        subtitle: "Dla tej gry"
                    )
                    
                    Spacer()
                    
                    MetricTile(
                        title: "Zestawy liczb",
                        value: "\(selectedGameLinesCount)",
                        subtitle: "Dla tej gry"
                    )
                }
            }
        }
    }
    
    private var gameInfoCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kumulacja i informacje")
                        .font(.headline)
                    
                    Text(viewModel.selectedGame.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                HStack {
                    MetricTile(
                        title: "Główna pula",
                        value: moneyText(viewModel.jackpotInfo?.jackpotValue ?? viewModel.gameInfo?.closestPrizeValue),
                        subtitle: "Najbliższe losowanie"
                    )
                    
                    Spacer()
                    
                    if viewModel.selectedGame == .lotto {
                        MetricTile(
                            title: "Lotto Plus",
                            value: moneyText(viewModel.jackpotInfo?.jackpotPlusValue),
                            subtitle: "Dodatkowa pula"
                        )
                    } else {
                        MetricTile(
                            title: "Najbliższa data",
                            value: shortDateText(viewModel.jackpotInfo?.closestDraw ?? viewModel.gameInfo?.nextDrawDate),
                            subtitle: "Losowanie"
                        )
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    if let couponPrice = viewModel.gameInfo?.couponPrice {
                        infoRow(
                            icon: "ticket.fill",
                            title: "Cena zakładu",
                            value: couponPrice
                        )
                    }
                    
                    if let draws = viewModel.gameInfo?.draws {
                        infoRow(
                            icon: "calendar",
                            title: "Losowania",
                            value: draws
                        )
                    }
                    
                    if let poolType = viewModel.gameInfo?.closestPrizePoolType {
                        infoRow(
                            icon: "info.circle.fill",
                            title: "Typ puli",
                            value: poolTypeText(poolType)
                        )
                    }
                }
                
                if viewModel.gameInfo == nil && viewModel.jackpotInfo == nil {
                    Text("Brak dodatkowych informacji dla tej gry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var recentHighWinsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ostatnie wysokie wygrane")
                            .font(.headline)
                        
                        Text("Najnowsze odnotowane wygrane z API LOTTO.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
                
                if viewModel.highestWins.isEmpty {
                    Text("Brak danych o ostatnich wysokich wygranych.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    let visibleWins = Array(viewModel.highestWins.prefix(5))
                    
                    ForEach(Array(visibleWins.enumerated()), id: \.element.id) { index, win in
                        HighestWinHomeRow(
                            index: index + 1,
                            win: win
                        )
                        
                        if win.id != visibleWins.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    private var todayTicketsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kupony na dzisiaj")
                            .font(.headline)
                        
                        Text(todayTicketsTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !todayTickets.isEmpty {
                        Text("Dzisiaj")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                if todayTickets.isEmpty {
                    Text("Nie masz zapisanych kuponów przypisanych do dzisiejszych losowań.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        MetricTile(
                            title: "Kupony",
                            value: "\(todayTickets.count)",
                            subtitle: "Na dziś"
                        )
                        
                        Spacer()
                        
                        MetricTile(
                            title: "Zestawy liczb",
                            value: "\(todayTicketsLinesCount)",
                            subtitle: "Na dziś"
                        )
                    }
                    
                    Divider()
                    
                    ForEach(Array(todayTickets.prefix(3))) { ticket in
                        NavigationLink {
                            TicketDetailView(
                                ticket: ticket,
                                checkResult: ticketChecker.check(ticket: ticket)
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ticket.gameName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("\(ticket.lines.count) zest. • \(ticket.drawDates.count) los.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if ticket.includesPlus {
                                    Text("Plus")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    
                    if todayTickets.count > 3 {
                        Text("I jeszcze \(todayTickets.count - 3) kuponów w zakładce Kupony.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var bestResultCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Najlepszy wynik")
                            .font(.headline)
                        
                        Text("Najwięcej trafień na zapisanych kuponach.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
                
                if let bestResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bestResult.titleText)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text(bestResult.drawDate.formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(bestResult.scoreText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                } else {
                    Text("Brak sprawdzonych kuponów. Gdy pojawią się wyniki dla zapisanych kuponów, pokażemy tutaj najlepsze trafienie.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var myTicketsSummaryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Moje kupony")
                        .font(.headline)
                    
                    Text("Krótkie podsumowanie zapisanych kuponów.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    MetricTile(
                        title: "Kupony",
                        value: "\(totalTicketsCount)",
                        subtitle: "Wszystkie"
                    )
                    
                    Spacer()
                    
                    MetricTile(
                        title: "Zestawy",
                        value: "\(totalLinesCount)",
                        subtitle: "Łącznie"
                    )
                }
                
                Divider()
                
                HStack {
                    MetricTile(
                        title: "Aktywne",
                        value: "\(activeTicketsCount)",
                        subtitle: "Przyszłe losowania"
                    )
                    
                    Spacer()
                    
                    MetricTile(
                        title: "Sprawdzone",
                        value: "\(checkedTicketsCount)",
                        subtitle: "Pełne wyniki"
                    )
                }
                
                if partiallyCheckedTicketsCount > 0 || waitingTicketsCount > 0 {
                    Divider()
                    
                    HStack {
                        MetricTile(
                            title: "Częściowe",
                            value: "\(partiallyCheckedTicketsCount)",
                            subtitle: "Część wyników"
                        )
                        
                        Spacer()
                        
                        MetricTile(
                            title: "Oczekujące",
                            value: "\(waitingTicketsCount)",
                            subtitle: "Brak wyników"
                        )
                    }
                }
            }
        }
    }
    
    private var gameSummaryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Według gier")
                        .font(.headline)
                    
                    Text("Podział Twoich kuponów na gry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                ForEach(Array(gameSummaries.enumerated()), id: \.element.id) { index, summary in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.game.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("\(summary.ticketsCount) kuponów • \(summary.linesCount) zestawów")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(summary.activeTicketsCount) aktyw.")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    if index < gameSummaries.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
    
    private var upcomingDrawsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Najbliższe losowania")
                        .font(.headline)
                    
                    Text("Szybki podgląd terminów dla wszystkich gier.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if upcomingDrawItems.isEmpty {
                    Text("Brak dostępnych dat losowań.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(upcomingDrawItems.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.game.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(item.date.formatted(date: .long, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(item.relativeText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(relativeBackground(for: item.date))
                                .clipShape(Capsule())
                        }
                        
                        if index < upcomingDrawItems.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    private var dataSourceSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Źródło danych")
                    .font(.headline)
                
                Text(viewModel.dataSourceName)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Jeżeli w Secrets.plist jest poprawny klucz API, aplikacja używa prawdziwego API LOTTO. W przeciwnym razie działa na danych testowych.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func infoRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
    }
    
    private func moneyText(_ value: Double?) -> String {
        guard let value else {
            return "Brak danych"
        }
        
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .currency
        formatter.currencyCode = "PLN"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value)) zł"
    }
    
    private func shortDateText(_ date: Date?) -> String {
        guard let date else {
            return "Brak danych"
        }
        
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    private func poolTypeText(_ value: String) -> String {
        switch value {
        case "Guaranteed":
            return "Gwarantowana"
        default:
            return value
        }
    }
    
    private func hitName(for count: Int) -> String {
        switch count {
        case 0:
            return "Brak trafień"
        case 1:
            return "Jedynka"
        case 2:
            return "Dwójka"
        case 3:
            return "Trójka"
        case 4:
            return "Czwórka"
        case 5:
            return "Piątka"
        case 6:
            return "Szóstka"
        default:
            return "\(count) trafień"
        }
    }
    
    private func relativeText(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let drawDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: drawDay).day ?? 0
        
        if days == 0 {
            return "Dzisiaj"
        } else if days == 1 {
            return "Jutro"
        } else if days > 1 {
            return "Za \(days) dni"
        } else {
            return "Minęło"
        }
    }
    
    private func relativeBackground(for date: Date?) -> Color {
        guard let date else {
            return Color.gray.opacity(0.15)
        }
        
        switch relativeText(for: date) {
        case "Dzisiaj":
            return Color.green.opacity(0.2)
        case "Jutro":
            return Color.orange.opacity(0.2)
        case "Minęło":
            return Color.gray.opacity(0.2)
        default:
            return Color.blue.opacity(0.15)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GameTicketSummary: Identifiable {
    let id = UUID()
    let game: LottoGame
    let ticketsCount: Int
    let linesCount: Int
    let activeTicketsCount: Int
}

private struct UpcomingDrawItem: Identifiable {
    let id = UUID()
    let game: LottoGame
    let date: Date
    
    var relativeText: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let drawDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: drawDay).day ?? 0
        
        if days == 0 {
            return "Dzisiaj"
        } else if days == 1 {
            return "Jutro"
        } else if days > 1 {
            return "Za \(days) dni"
        } else {
            return "Minęło"
        }
    }
}

private struct HighestWinHomeRow: View {
    let index: Int
    let win: LottoHighestWin
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(win.gameType)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    
                    if let rank = win.rank,
                       !rank.isEmpty,
                       rank.lowercased() != "brak" {
                        Text(rank)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
                
                Text(placeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let winDate = win.winDateUtc {
                    Text(winDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(moneyText(win.amountFixed))
                .font(.subheadline)
                .fontWeight(.bold)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private var placeText: String {
        let place = win.place?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let address = win.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if !place.isEmpty && place != "-" {
            return place
        }
        
        if !address.isEmpty && address != "-" {
            return address
        }
        
        return "Brak lokalizacji"
    }
    
    private func moneyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .currency
        formatter.currencyCode = "PLN"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) zł"
    }
}

#Preview {
    ContentView()
}
