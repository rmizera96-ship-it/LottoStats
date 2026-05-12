import SwiftUI

struct ContentView: View {
    @State private var selectedGame = "Lotto"
    
    let games = ["Lotto", "Mini Lotto", "Eurojackpot"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LottoStats")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Sprawdzaj wyniki losowań i statystyki liczb")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Picker("Gra", selection: $selectedGame) {
                        ForEach(games, id: \.self) { game in
                            Text(game)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(spacing: 12) {
                        InfoCard(
                            title: "Ostatnie losowanie",
                            value: "Brak danych",
                            subtitle: "Dane pojawią się po podłączeniu API"
                        )
                        
                        InfoCard(
                            title: "Najczęstsze liczby",
                            value: "-",
                            subtitle: "Tutaj pokażemy statystyki"
                        )
                        
                        InfoCard(
                            title: "Twoje kupony",
                            value: "0",
                            subtitle: "W przyszłości dodamy zapis własnych liczb"
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Start")
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}
