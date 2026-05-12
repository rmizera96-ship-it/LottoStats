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
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(draw.gameName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        ForEach(draw.numbers, id: \.self) { number in
                            NumberBall(number: number, style: .lotto, size: 34)
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
