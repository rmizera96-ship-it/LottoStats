import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = LottoDataViewModel()
    
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
                
                Picker("Gra", selection: selectedGameBinding) {
                    ForEach(repository.availableGames()) { game in
                        Text(game.displayName)
                            .tag(game)
                    }
                }
                .pickerStyle(.segmented)
                
                AppCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Źródło danych")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(viewModel.dataSourceName)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await viewModel.refresh()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline)
                        }
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
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Brak historii")
                                .font(.headline)
                            
                            Text(viewModel.errorMessage ?? "Dla tej gry nie mamy jeszcze danych.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(viewModel.draws) { draw in
                        DrawHistoryRow(draw: draw)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Historia losowań")
        .task {
            await viewModel.loadInitialData()
        }
    }
}

struct DrawHistoryRow: View {
    let draw: DrawResult
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draw.gameName)
                            .font(.headline)
                        
                        Text(draw.drawDate.formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if let drawSystemId = draw.drawSystemId {
                        Text("ID \(drawSystemId)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Liczby główne")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        ForEach(draw.numbers, id: \.self) { number in
                            NumberBall(number: number, style: .lotto, size: 34)
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
                withAnimation {
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
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if prizes.isEmpty {
                    Text("Brak informacji o wygranych dla tego losowania.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            hasLoaded = true
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
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) zł"
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
