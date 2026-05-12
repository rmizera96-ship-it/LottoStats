import SwiftUI

struct ContentView: View {
    @State private var selectedGame = "Lotto"
    
    let games = ["Lotto", "Mini Lotto", "Eurojackpot"]
    let latestDraw = DrawResult.sample
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    headerView
                    
                    Picker("Gra", selection: $selectedGame) {
                        ForEach(games, id: \.self) { game in
                            Text(game)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    latestDrawCard
                    
                    NavigationLink {
                        HistoryView()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Zobacz historię losowań")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    VStack(spacing: 12) {
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
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LottoStats")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Sprawdzaj wyniki losowań i statystyki liczb")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var latestDrawCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ostatnie losowanie")
                .font(.headline)
            
            Text(latestDraw.gameName)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(latestDraw.drawDate.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                ForEach(latestDraw.numbers, id: \.self) { number in
                    Text("\(number)")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
