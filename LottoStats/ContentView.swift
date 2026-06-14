import SwiftUI

struct ContentView: View {
    @StateObject private var ticketViewModel = TicketViewModel()
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeView(ticketViewModel: ticketViewModel)
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
        .tint(AppTheme.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            await ticketViewModel.refreshTicketResults()
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = LottoDataViewModel(mode: .dashboard)
    @ObservedObject var ticketViewModel: TicketViewModel
    
    private let repository = LottoRepository.shared
    private let bestResultCalculator = BestResultCalculator()
    
    private var tickets: [LottoTicket] {
        ticketViewModel.tickets
    }
    
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
            let status = ticketViewModel.checkResult(for: ticket).status
            
            if case .active = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var checkedTicketsCount: Int {
        tickets.filter { ticket in
            let status = ticketViewModel.checkResult(for: ticket).status
            
            if case .checked = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var partiallyCheckedTicketsCount: Int {
        tickets.filter { ticket in
            let status = ticketViewModel.checkResult(for: ticket).status
            
            if case .partiallyChecked = status {
                return true
            }
            
            return false
        }.count
    }
    
    private var waitingTicketsCount: Int {
        tickets.filter { ticket in
            let status = ticketViewModel.checkResult(for: ticket).status
            
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
            
            let status = ticketViewModel.checkResult(for: ticket).status
            
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
            guard let date = viewModel.upcomingDrawDatesByGame[game]
                    ?? repository.upcomingDrawDates(for: game, count: 1).first else {
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
    
    private var bestResult: UserBestResult? {
        bestResultCalculator.calculate(
            from: tickets,
            checkResult: ticketViewModel.checkResult(for:)
        )
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                
                homeHeroSection
                
                mainDashboardCard
                
                latestDrawCard
                
                myTicketsDashboardCard
                
                upcomingDrawsCard
                
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Odśwież dane", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryActionButtonStyle(tint: viewModel.selectedGame.visualColor))
                
                Spacer()
            }
            .padding()
            .safeAreaPadding(.bottom, 110)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadInitialData()
            await viewModel.loadUpcomingDrawDatesForAllGames()
        }
    }
    
    private var homeHeroSection: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            viewModel.selectedGame.visualColor.opacity(0.25),
                            Color.indigo.opacity(0.12),
                            Color(.secondarySystemBackground).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(viewModel.selectedGame.visualColor.opacity(0.16))
                .frame(width: 180, height: 180)
                .blur(radius: 2)
                .offset(x: 72, y: -92)

            Circle()
                .fill(Color.purple.opacity(0.10))
                .frame(width: 110, height: 110)
                .offset(x: 34, y: 112)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("OFICJALNE DANE LOTTO", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(viewModel.selectedGame.visualColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedGame.visualColor.opacity(0.13))
                            .clipShape(Capsule())

                        Text("LottoStats")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text("Wyniki, kupony i statystyki w jednym miejscu.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(viewModel.selectedGame.visualGradient)

                        Image(systemName: viewModel.selectedGame.symbolName)
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 64, height: 64)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                            .offset(x: 7, y: -7)
                    }
                    .shadow(
                        color: viewModel.selectedGame.visualColor.opacity(0.34),
                        radius: 12,
                        x: 0,
                        y: 7
                    )
                }

                GameSelector(
                    games: games,
                    selection: selectedGameBinding
                )
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(viewModel.selectedGame.visualColor.opacity(0.22), lineWidth: 1)
        }
        .shadow(
            color: viewModel.selectedGame.visualColor.opacity(0.13),
            radius: 16,
            x: 0,
            y: 9
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedGame)
    }
    
    private var mainDashboardCard: some View {
        AppCard(tint: viewModel.selectedGame.visualColor) {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: viewModel.selectedGame.displayName,
                    subtitle: "Najbliższe losowanie",
                    icon: viewModel.selectedGame.symbolName,
                    tint: viewModel.selectedGame.visualColor
                ) {
                    Text(nextDrawRelativeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(viewModel.selectedGame.visualColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(relativeBackground(for: viewModel.nextDrawDate))
                        .clipShape(Capsule())
                }
                
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                        
                        Text("Ładowanie danych z API...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let nextDrawDate = viewModel.nextDrawDate {
                    Text(AppFormatters.polishLongDate.string(from: nextDrawDate))
                        .font(.title3)
                        .fontWeight(.semibold)
                } else {
                    Text("Brak dostępnej daty najbliższego losowania.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                HStack(alignment: .top) {
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
                            title: "Twoje kupony",
                            value: "\(selectedGameTicketsCount)",
                            subtitle: "Dla tej gry"
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
                }
            }
        }
    }
    
    private var latestDrawCard: some View {
        AppCard(tint: viewModel.selectedGame.visualColor) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    
                    Text("Ładowanie ostatniego losowania...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let latestDraw = viewModel.latestDraw {
                VStack(alignment: .leading, spacing: 14) {
                    CardHeader(
                        title: "Ostatnie losowanie",
                        subtitle: latestDraw.gameName,
                        icon: "clock.badge.checkmark",
                        tint: viewModel.selectedGame.visualColor
                    ) {
                        Text(AppFormatters.polishShortDate.string(from: latestDraw.drawDate))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.selectedGame.visualColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedGame.visualColor.opacity(0.11))
                            .clipShape(Capsule())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Liczby główne")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            ForEach(latestDraw.numbers, id: \.self) { number in
                                NumberBall(number: number, style: viewModel.selectedGame.ballStyle)
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
                VStack(spacing: 12) {
                    EmptyStateArtwork(
                        icon: "clock.arrow.circlepath",
                        tint: viewModel.selectedGame.visualColor,
                        size: 82
                    )

                    VStack(spacing: 5) {
                        Text("Brak ostatniego losowania")
                            .font(.headline)

                        Text(viewModel.errorMessage ?? "Nie udało się pobrać danych.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var myTicketsDashboardCard: some View {
        AppCard(tint: AppTheme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(
                    title: "Moje kupony",
                    subtitle: "Szybkie podsumowanie zapisanych kuponów",
                    icon: "ticket.fill",
                    tint: AppTheme.accent
                ) {
                    Text("\(totalTicketsCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.11))
                        .clipShape(Capsule())
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
                            subtitle: "Na wyniki"
                        )
                    }
                }
                
                Divider()
                
                HStack {
                    MetricTile(
                        title: "Najlepsze trafienie",
                        value: bestHitTitleText,
                        subtitle: bestHitSubtitleText
                    )
                    
                    Spacer()
                    
                    MetricTile(
                        title: "Na dzisiaj",
                        value: "\(todayTickets.count)",
                        subtitle: "\(todayTicketsLinesCount) zestawów"
                    )
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
                    let visibleWins = Array(viewModel.highestWins.prefix(4))
                    
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
    
    private var upcomingDrawsCard: some View {
        AppCard(tint: Color.indigo) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Najbliższe losowania",
                    subtitle: "Terminy dla wszystkich gier",
                    icon: "calendar",
                    tint: Color.indigo
                )
                
                if upcomingDrawItems.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundStyle(Color.indigo)
                            .frame(width: 34, height: 34)
                            .background(Color.indigo.opacity(0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text("Brak dostępnych dat losowań.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(Array(upcomingDrawItems.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: item.game.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(item.game.visualColor)
                                    .frame(width: 32, height: 32)
                                    .background(item.game.visualColor.opacity(0.11))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.game.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text(AppFormatters.polishLongDate.string(from: item.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
    
    private var compactDataSourceCard: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Źródło danych")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.dataSourceName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
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
                .foregroundStyle(viewModel.selectedGame.visualColor)
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
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.72)
                .lineLimit(2)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .background(AppTheme.accent)
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
                    Text(AppFormatters.polishShortDate.string(from: winDate))
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
