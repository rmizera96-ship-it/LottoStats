import SwiftUI
import Combine

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    
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
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                gamePickerSection
                
                if viewModel.isLoading {
                    loadingSection
                } else if let errorMessage = viewModel.errorMessage {
                    errorSection(message: errorMessage)
                } else if viewModel.stats == nil {
                    emptySection
                } else {
                    summaryCard
                    mostFrequentCard
                    leastFrequentCard
                    
                    if !viewModel.specialFrequencyItems.isEmpty {
                        specialNumbersCard
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Statystyki")
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statystyki")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Statystyki liczb pobierane bezpośrednio z API LOTTO.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var gamePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gra")
                .font(.headline)
            
            Picker("Gra", selection: selectedGameBinding) {
                ForEach(LottoGame.allCases) { game in
                    Text(game.displayName)
                        .tag(game)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
    
    private var loadingSection: some View {
        StatisticsCard {
            HStack(spacing: 12) {
                ProgressView()
                
                Text("Ładowanie statystyk...")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func errorSection(message: String) -> some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Błąd")
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var emptySection: some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Brak danych")
                    .font(.headline)
                
                Text("Nie udało się pobrać statystyk dla wybranej gry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var summaryCard: some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("PODSUMOWANIE")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text(viewModel.drawCountText)
                    .font(.system(size: 32, weight: .bold))
                
                Text("Analizowany okres: \(viewModel.periodText)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("Źródło: \(viewModel.dataSourceName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var mostFrequentCard: some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Najczęściej losowane")
                    .font(.title2)
                    .fontWeight(.bold)
                
                FrequencyGrid(
                    items: viewModel.mostFrequentMainItems,
                    circleColor: .green
                )
            }
        }
    }
    
    private var leastFrequentCard: some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Najrzadziej losowane")
                    .font(.title2)
                    .fontWeight(.bold)
                
                FrequencyGrid(
                    items: viewModel.leastFrequentMainItems,
                    circleColor: Color(.systemGray)
                )
            }
        }
    }
    
    private var specialNumbersCard: some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 18) {
                Text(viewModel.specialNumbersTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                FrequencyGrid(
                    items: viewModel.specialFrequencyItems,
                    circleColor: .purple
                )
            }
        }
    }
}

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var selectedGame: LottoGame = .lotto
    @Published private(set) var stats: LottoFrequencyStats?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let repository: LottoRepository
    
    init() {
        self.repository = LottoRepository.shared
    }
    
    init(repository: LottoRepository) {
        self.repository = repository
    }
    
    var dataSourceName: String {
        repository.dataSourceName
    }
    
    var mostFrequentMainItems: [LottoFrequencyItem] {
        Array((stats?.mainNumbers ?? []).prefix(10))
    }
    
    var leastFrequentMainItems: [LottoFrequencyItem] {
        Array(stats?.mainNumbers ?? [])
            .sorted { first, second in
                if first.numberOfOccurrences == second.numberOfOccurrences {
                    return first.number < second.number
                }
                
                return first.numberOfOccurrences < second.numberOfOccurrences
            }
            .prefix(10)
            .map { $0 }
    }
    
    var specialFrequencyItems: [LottoFrequencyItem] {
        Array((stats?.specialNumbers ?? []).prefix(10))
    }
    
    var specialNumbersTitle: String {
        switch selectedGame {
        case .eurojackpot:
            return "Najczęściej losowane euroliczby"
        case .lotto:
            return "Najczęściej losowane liczby specjalne"
        case .miniLotto:
            return "Najczęściej losowane liczby specjalne"
        }
    }
    
    var drawCountText: String {
        let count = stats?.totalDraws ?? 0
        
        switch count {
        case 1:
            return "1 losowanie"
        case 2...4:
            return "\(count) losowania"
        default:
            return "\(count) losowań"
        }
    }
    
    var periodText: String {
        guard let stats else {
            return "Brak danych"
        }
        
        let start = stats.dateFrom.formatted(date: .abbreviated, time: .omitted)
        let end = stats.dateTo.formatted(date: .abbreviated, time: .omitted)
        
        return "\(start) – \(end)"
    }
    
    func loadInitialData() async {
        if stats == nil {
            await loadData(for: selectedGame)
        }
    }
    
    func selectGame(_ game: LottoGame) async {
        selectedGame = game
        await loadData(for: game)
    }
    
    private func loadData(for game: LottoGame) async {
        isLoading = true
        errorMessage = nil
        
        do {
            stats = try await repository.fetchNumberFrequencyStats(for: game)
            
            if stats == nil {
                errorMessage = "Brak statystyk dla gry \(game.displayName)."
            }
        } catch {
            stats = nil
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct StatisticsCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct FrequencyGrid: View {
    let items: [LottoFrequencyItem]
    let circleColor: Color
    
    private let columns = [
        GridItem(.adaptive(minimum: 62), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(items) { item in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(circleColor)
                            .frame(width: 62, height: 62)
                        
                        Text("\(item.number)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text("\(item.numberOfOccurrences)x")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(percentText(for: item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func percentText(for item: LottoFrequencyItem) -> String {
        let percent = item.percentOfOccurrences
        
        if percent.rounded() == percent {
            return "\(Int(percent))%"
        }
        
        return String(format: "%.1f%%", percent)
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
