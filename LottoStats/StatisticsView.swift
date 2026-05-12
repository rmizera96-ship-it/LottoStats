import SwiftUI

struct NumberFrequency: Identifiable {
    let number: Int
    let count: Int
    
    var id: Int {
        number
    }
    
    static func calculate(from draws: [DrawResult]) -> [NumberFrequency] {
        let allNumbers = draws.flatMap { $0.numbers }
        return calculate(fromNumbers: allNumbers)
    }
    
    static func calculate(fromNumbers numbers: [Int]) -> [NumberFrequency] {
        let groupedNumbers = Dictionary(grouping: numbers, by: { $0 })
        
        return groupedNumbers
            .map { NumberFrequency(number: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.number < $1.number
                } else {
                    return $0.count > $1.count
                }
            }
    }
}

struct StatisticsView: View {
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
    
    private var mainFrequencies: [NumberFrequency] {
        NumberFrequency.calculate(from: viewModel.draws)
    }
    
    private var plusFrequencies: [NumberFrequency] {
        let plusNumbers = viewModel.draws.flatMap { draw in
            draw.plusNumbers ?? []
        }
        
        return NumberFrequency.calculate(fromNumbers: plusNumbers)
    }
    
    private var extraFrequencies: [NumberFrequency] {
        let extraNumbers = viewModel.draws.flatMap { draw in
            draw.extraNumbers ?? []
        }
        
        return NumberFrequency.calculate(fromNumbers: extraNumbers)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
                Picker("Gra", selection: selectedGameBinding) {
                    ForEach(repository.availableGames()) { game in
                        Text(game.displayName)
                            .tag(game)
                    }
                }
                .pickerStyle(.segmented)
                
                dataSourceCard
                
                if viewModel.isLoading {
                    loadingCard
                } else if viewModel.draws.isEmpty {
                    emptyCard
                } else {
                    frequencySection(
                        title: "Najczęstsze liczby główne",
                        subtitle: "Ranking podstawowych liczb dla gry \(viewModel.selectedGame.displayName).",
                        frequencies: mainFrequencies,
                        style: .lotto
                    )
                    
                    if viewModel.selectedGame.supportsPlus && !plusFrequencies.isEmpty {
                        frequencySection(
                            title: "Najczęstsze liczby Lotto Plus",
                            subtitle: "Ranking liczb z dodatkowego losowania Lotto Plus.",
                            frequencies: plusFrequencies,
                            style: .plus
                        )
                    }
                    
                    if !extraFrequencies.isEmpty {
                        frequencySection(
                            title: "Najczęstsze euroliczby",
                            subtitle: "Ranking dodatkowych euroliczb dla Eurojackpot.",
                            frequencies: extraFrequencies,
                            style: .plus
                        )
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
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Najczęstsze liczby")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Ranking na podstawie historii wybranej gry.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var dataSourceCard: some View {
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
    }
    
    private var loadingCard: some View {
        AppCard {
            HStack {
                ProgressView()
                Text("Ładowanie statystyk...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var emptyCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Brak statystyk")
                    .font(.headline)
                
                Text(viewModel.errorMessage ?? "Dla tej gry nie mamy jeszcze danych.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func frequencySection(
        title: String,
        subtitle: String,
        frequencies: [NumberFrequency],
        style: NumberBallStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(frequencies) { item in
                frequencyRow(
                    item,
                    maxCount: maxCount(for: frequencies),
                    style: style
                )
            }
        }
    }
    
    private func frequencyRow(
        _ item: NumberFrequency,
        maxCount: Int,
        style: NumberBallStyle
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    NumberBall(number: item.number, style: style, size: 42)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Liczba \(item.number)")
                            .font(.headline)
                        
                        Text("Wystąpiła \(item.count) razy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(item.count)x")
                        .font(.headline)
                }
                
                ProgressView(value: Double(item.count), total: Double(maxCount))
            }
        }
    }
    
    private func maxCount(for frequencies: [NumberFrequency]) -> Int {
        frequencies.map { $0.count }.max() ?? 1
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
