import SwiftUI

struct NumberFrequency: Identifiable {
    let number: Int
    let count: Int
    
    var id: Int {
        number
    }
    
    static func calculate(from draws: [DrawResult]) -> [NumberFrequency] {
        let allNumbers = draws.flatMap { $0.numbers }
        let groupedNumbers = Dictionary(grouping: allNumbers, by: { $0 })
        
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
    
    private var frequencies: [NumberFrequency] {
        NumberFrequency.calculate(from: viewModel.draws)
    }
    
    private var maxCount: Int {
        frequencies.map { $0.count }.max() ?? 1
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Najczęstsze liczby")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Ranking na podstawie historii wybranej gry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
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
                            Text("Ładowanie statystyk...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if frequencies.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Brak statystyk")
                                .font(.headline)
                            
                            Text(viewModel.errorMessage ?? "Dla tej gry nie mamy jeszcze danych.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(frequencies) { item in
                        frequencyRow(item)
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
    
    private func frequencyRow(_ item: NumberFrequency) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    NumberBall(number: item.number, style: .lotto, size: 42)
                    
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
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
}
