import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = LottoDataViewModel(mode: .history)
    
    private let repository = LottoRepository.shared
    
    private var selectedGameBinding: Binding<LottoGame> {
        Binding {
            viewModel.selectedGame
        } set: { game in
            Task {
                await viewModel.selectGame(game)
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Historia losowań",
                    subtitle: "Wyniki oraz szczegóły wygranych z oficjalnego API LOTTO.",
                    icon: "clock.arrow.circlepath",
                    tint: viewModel.selectedGame.visualColor
                )

                GameSelector(
                    games: repository.availableGames(),
                    selection: selectedGameBinding
                )

                AppCard(tint: viewModel.selectedGame.visualColor) {
                    CardHeader(
                        title: "Historia z API LOTTO",
                        subtitle: "Źródło: \(viewModel.dataSourceName)",
                        icon: "clock.badge.checkmark",
                        tint: viewModel.selectedGame.visualColor
                    ) {
                        IconCircleButton(
                            systemImage: "arrow.clockwise",
                            tint: viewModel.selectedGame.visualColor,
                            isLoading: viewModel.isLoading
                        ) {
                            Task {
                                await viewModel.refresh()
                            }
                        }
                        .accessibilityLabel("Odśwież historię")
                    }
                }
                
                if viewModel.isLoading {
                    AppCard {
                        HStack {
                            ProgressView()
                            Text("Ładowanie historii...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if viewModel.draws.isEmpty {
                    EmptyStateCard(
                        title: "Brak historii losowań",
                        message: viewModel.errorMessage ?? "Dla tej gry nie mamy jeszcze danych. Spróbuj odświeżyć widok za chwilę.",
                        icon: "clock.arrow.circlepath",
                        tint: viewModel.selectedGame.visualColor
                    )
                } else {
                    ForEach(viewModel.draws) { draw in
                        DrawHistoryRow(draw: draw)
                    }
                }
            }
            .padding()
            .safeAreaPadding(.bottom, 110)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadInitialData()
        }
    }
}

struct DrawHistoryRow: View {
    let draw: DrawResult

    var body: some View {
        AppCard(tint: draw.game.visualColor) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    title: draw.gameName,
                    subtitle: AppFormatters.polishLongDate.string(from: draw.drawDate),
                    icon: draw.game.symbolName,
                    tint: draw.game.visualColor
                ) {
                    if let drawSystemId = draw.drawSystemId {
                        Text("#\(drawSystemId)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(draw.game.visualColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(draw.game.visualColor.opacity(0.11))
                            .clipShape(Capsule())
                            .accessibilityLabel("Numer losowania \(drawSystemId)")
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Liczby główne")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        ForEach(draw.numbers, id: \.self) { number in
                            NumberBall(number: number, style: draw.game.ballStyle, size: 34)
                        }
                    }
                }
                
                if let extraNumbers = draw.extraNumbers,
                   !extraNumbers.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Euroliczby")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            ForEach(extraNumbers, id: \.self) { number in
                                NumberBall(number: number, style: .plus, size: 34)
                            }
                        }
                    }
                }
                
                if let plusNumbers = draw.plusNumbers,
                   draw.game.supportsPlus {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lotto Plus")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            ForEach(plusNumbers, id: \.self) { number in
                                NumberBall(number: number, style: .plus, size: 34)
                            }
                        }
                    }
                }
                
                Divider()
                
                DrawPrizesSection(draw: draw)
            }
        }
    }
}

struct DrawPrizesSection: View {
    let draw: DrawResult
    
    @State private var isExpanded = false
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var prizes: [LottoDrawPrizeInfo] = []
    @State private var errorMessage: String?
    
    private let repository = LottoRepository.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
                
                if isExpanded && !hasLoaded {
                    Task {
                        await loadPrizes()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    
                    Text(isExpanded ? "Ukryj wygrane" : "Pokaż wygrane")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)

            if isExpanded {
                if draw.drawSystemId == nil {
                    Text("Brak identyfikatora losowania. Wygrane są dostępne tylko dla danych pobranych z API LOTTO.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isLoading {
                    HStack {
                        ProgressView()
                        Text("Ładowanie wygranych...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)

                        Button {
                            Task {
                                await loadPrizes()
                            }
                        } label: {
                            Label("Spróbuj ponownie", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                    }
                } else if prizes.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy")
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                        Text("Brak informacji o wygranych dla tego losowania.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(prizes) { prizeInfo in
                        PrizeGameSection(prizeInfo: prizeInfo)
                    }
                }
            }
        }
    }
    
    private func loadPrizes() async {
        guard draw.drawSystemId != nil else {
            hasLoaded = true
            prizes = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            prizes = try await repository.fetchDrawPrizes(for: draw)
            hasLoaded = true
        } catch {
            prizes = []
            errorMessage = error.localizedDescription
            hasLoaded = false
        }
        
        isLoading = false
    }
}

struct PrizeGameSection: View {
    let prizeInfo: LottoDrawPrizeInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prizeInfo.gameType)
                .font(.subheadline)
                .fontWeight(.bold)
            
            ForEach(prizeInfo.ranks) { rank in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rankName(rank.rank))
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(winnersText(rank.winnersCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(moneyText(rank.prizeValue))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.trailing)
                }
                
                if rank.id != prizeInfo.ranks.last?.id {
                    Divider()
                }
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground).opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
        }
    }
    
    private func rankName(_ rank: String) -> String {
        switch rank {
        case "1":
            return "I stopień"
        case "2":
            return "II stopień"
        case "3":
            return "III stopień"
        case "4":
            return "IV stopień"
        case "5":
            return "V stopień"
        case "6":
            return "VI stopień"
        case "7":
            return "VII stopień"
        case "8":
            return "VIII stopień"
        case "9":
            return "IX stopień"
        case "10":
            return "X stopień"
        case "11":
            return "XI stopień"
        case "12":
            return "XII stopień"
        default:
            return "\(rank) stopień"
        }
    }
    
    private func winnersText(_ count: Int) -> String {
        switch count {
        case 0:
            return "Brak wygranych"
        case 1:
            return "1 wygrana"
        case 2...4:
            return "\(count) wygrane"
        default:
            return "\(count) wygranych"
        }
    }
    
    private func moneyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .currency
        formatter.currencyCode = "PLN"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) zł"
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
