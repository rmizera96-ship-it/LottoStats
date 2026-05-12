import SwiftUI

struct HistoryView: View {
    @State private var selectedGame: LottoGame = .lotto
    
    private let repository = LottoRepository.shared
    
    private var draws: [DrawResult] {
        repository.draws(for: selectedGame)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                Picker("Gra", selection: $selectedGame) {
                    ForEach(repository.availableGames()) { game in
                        Text(game.displayName)
                            .tag(game)
                    }
                }
                .pickerStyle(.segmented)
                
                if draws.isEmpty {
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Brak historii")
                                .font(.headline)
                            
                            Text("Dla gry \(selectedGame.displayName) nie mamy jeszcze danych testowych.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(draws) { draw in
                        DrawHistoryRow(draw: draw)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Historia losowań")
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
                    Text("Lotto")
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
