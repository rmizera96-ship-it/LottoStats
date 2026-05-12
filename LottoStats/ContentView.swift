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
    
    private var mostFrequentNumberText: String {
        let mostFrequent = NumberFrequency.calculate(from: viewModel.draws).first
        return mostFrequent.map { "\($0.number)" } ?? "-"
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
    
    private var plusTicketsCount: Int {
        tickets.filter { $0.includesPlus }.count
    }
    
    private var eurojackpotTicketsCount: Int {
        tickets.filter { $0.game == .eurojackpot }.count
    }
    
    private var selectedGameTicketsCount: Int {
        tickets.filter { $0.game == viewModel.selectedGame }.count
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
                
                nextDrawCard
                
                upcomingDrawsCard
                
                latestDrawCard
                
                dashboardSection
                
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
            
            Text("Sprawdzaj wyniki losowań, statystyki liczb i swoje kupony.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(selectedGameActiveTicketsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Aktywne kupony")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(selectedGameLinesCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Zestawy liczb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("Podsumowanie dotyczy aktualnie wybranej gry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Text("Ostatnie losowanie")
                        .font(.headline)
                    
                    Text(latestDraw.gameName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(latestDraw.drawDate.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
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
    
    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Podsumowanie")
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoCard(
                    title: "Najczęstsza liczba",
                    value: mostFrequentNumberText,
                    subtitle: "Na podstawie historii wybranej gry"
                )
                
                InfoCard(
                    title: "Kupony",
                    value: "\(totalTicketsCount)",
                    subtitle: "Liczba zapisanych kuponów"
                )
                
                InfoCard(
                    title: "Zestawy liczb",
                    value: "\(totalLinesCount)",
                    subtitle: "Łączna liczba zestawów na kuponach"
                )
                
                InfoCard(
                    title: "Kupony dla \(viewModel.selectedGame.displayName)",
                    value: "\(selectedGameTicketsCount)",
                    subtitle: "Zapisane kupony dla aktualnie wybranej gry"
                )
                
                InfoCard(
                    title: "Aktywne kupony",
                    value: "\(activeTicketsCount)",
                    subtitle: "Kupony na przyszłe losowania"
                )
                
                InfoCard(
                    title: "Sprawdzone kupony",
                    value: "\(checkedTicketsCount)",
                    subtitle: "Kupony, dla których mamy wszystkie wyniki"
                )
                
                InfoCard(
                    title: "Częściowo sprawdzone",
                    value: "\(partiallyCheckedTicketsCount)",
                    subtitle: "Kupony z częścią wyników"
                )
                
                InfoCard(
                    title: "Oczekujące na wyniki",
                    value: "\(waitingTicketsCount)",
                    subtitle: "Kupony po dacie losowania bez wyniku w aplikacji"
                )
                
                InfoCard(
                    title: "Kupony z Lotto Plus",
                    value: "\(plusTicketsCount)",
                    subtitle: "Kupony z zaznaczoną opcją Plus"
                )
                
                InfoCard(
                    title: "Kupony Eurojackpot",
                    value: "\(eurojackpotTicketsCount)",
                    subtitle: "Kupony z euroliczbami"
                )
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

#Preview {
    ContentView()
}
