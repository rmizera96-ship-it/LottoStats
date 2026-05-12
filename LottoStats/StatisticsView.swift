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
                } else if viewModel.draws.isEmpty {
                    emptySection
                } else {
                    summaryCard
                    mostFrequentCard
                    leastFrequentCard
                    
                    if !viewModel.extraFrequencyItems.isEmpty {
                        extraNumbersCard
                    }
                    
                    if !viewModel.plusFrequencyItems.isEmpty {
                        plusNumbersCard
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
            
            Text("Przegląd najczęściej i najrzadziej losowanych liczb.")
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
                
                Text("Nie udało się znaleźć losowań dla wybranej gry.")
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
                
                Text("Analizowany okres: \(viewModel.yearRangeText)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("Gra: \(viewModel.selectedGame.displayName)")
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
    
    private var extraNumbersCard: some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Najczęściej losowane euroliczby")
                    .font(.title2)
                    .fontWeight(.bold)
                
                FrequencyGrid(
                    items: viewModel.extraFrequencyItems,
                    circleColor: .purple
                )
            }
        }
    }
    
    private var plusNumbersCard: some View {
        StatisticsCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Najczęściej losowane Lotto Plus")
                    .font(.title2)
                    .fontWeight(.bold)
                
                FrequencyGrid(
                    items: viewModel.plusFrequencyItems,
                    circleColor: .blue
                )
            }
        }
    }
}

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var selectedGame: LottoGame = .lotto
    @Published private(set) var draws: [DrawResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let repository: LottoRepository
    
    init() {
        self.repository = LottoRepository.shared
    }
    
    init(repository: LottoRepository) {
        self.repository = repository
    }
    
    var mostFrequentMainItems: [StatisticsFrequencyItem] {
        frequencyItems(from: draws.flatMap { $0.numbers })
            .prefix(10)
            .map { $0 }
    }
    
    var leastFrequentMainItems: [StatisticsFrequencyItem] {
        Array(
            frequencyItems(from: draws.flatMap { $0.numbers })
                .suffix(10)
        )
        .sorted { first, second in
            if first.count == second.count {
                return first.number < second.number
            }
            
            return first.count < second.count
        }
    }
    
    var extraFrequencyItems: [StatisticsFrequencyItem] {
        frequencyItems(from: draws.compactMap(\.extraNumbers).flatMap { $0 })
            .prefix(10)
            .map { $0 }
    }
    
    var plusFrequencyItems: [StatisticsFrequencyItem] {
        frequencyItems(from: draws.compactMap(\.plusNumbers).flatMap { $0 })
            .prefix(10)
            .map { $0 }
    }
    
    var drawCountText: String {
        let count = draws.count
        
        switch count {
        case 1:
            return "1 losowanie"
        case 2...4:
            return "\(count) losowania"
        default:
            return "\(count) losowań"
        }
    }
    
    var yearRangeText: String {
        let years = draws.map {
            Calendar.current.component(.year, from: $0.drawDate)
        }
        
        guard let minYear = years.min(),
              let maxYear = years.max() else {
            return "Brak danych"
        }
        
        if minYear == maxYear {
            return "\(minYear)"
        }
        
        return "\(minYear)–\(maxYear)"
    }
    
    func loadInitialData() async {
        if draws.isEmpty {
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
            let fetchedDraws = try await repository.fetchDraws(for: game)
            draws = fetchedDraws
        } catch {
            draws = []
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func frequencyItems(from numbers: [Int]) -> [StatisticsFrequencyItem] {
        let grouped = Dictionary(grouping: numbers, by: { $0 })
        
        return grouped
            .map { number, values in
                StatisticsFrequencyItem(
                    number: number,
                    count: values.count
                )
            }
            .sorted { first, second in
                if first.count == second.count {
                    return first.number < second.number
                }
                
                return first.count > second.count
            }
    }
}

struct StatisticsFrequencyItem: Identifiable {
    let id = UUID()
    let number: Int
    let count: Int
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
    let items: [StatisticsFrequencyItem]
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
                    
                    Text("\(item.count)x")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
