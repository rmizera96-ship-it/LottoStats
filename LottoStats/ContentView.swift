import SwiftUI

struct ContentView: View {
    @State private var selectedGame = "Lotto"
    @State private var tickets = LottoTicket.samples
    
    let games = ["Lotto", "Mini Lotto", "Eurojackpot"]
    let latestDraw = DrawResult.sample
    
    private var mostFrequentNumberText: String {
        let mostFrequent = NumberFrequency.calculate(from: DrawResult.samples).first
        return mostFrequent.map { "\($0.number)" } ?? "-"
    }
    
    private var activeTicketsCount: Int {
        tickets.filter { ticket in
            let today = Calendar.current.startOfDay(for: Date())
            let drawDay = Calendar.current.startOfDay(for: ticket.drawDate)
            let hasResult = DrawResult.result(
                for: ticket.gameName,
                drawDate: ticket.drawDate
            ) != nil
            
            return drawDay >= today && !hasResult
        }.count
    }
    
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
                        MenuButton(
                            icon: "clock.arrow.circlepath",
                            title: "Zobacz historię losowań"
                        )
                    }
                    
                    NavigationLink {
                        StatisticsView()
                    } label: {
                        MenuButton(
                            icon: "chart.bar.xaxis",
                            title: "Zobacz statystyki liczb"
                        )
                    }
                    
                    NavigationLink {
                        MyTicketsView(tickets: $tickets)
                    } label: {
                        MenuButton(
                            icon: "ticket.fill",
                            title: "Moje kupony"
                        )
                    }
                    
                    VStack(spacing: 12) {
                        InfoCard(
                            title: "Najczęstsza liczba",
                            value: mostFrequentNumberText,
                            subtitle: "Na podstawie historii losowań"
                        )
                        
                        InfoCard(
                            title: "Aktywne kupony",
                            value: "\(activeTicketsCount)",
                            subtitle: "Kupony na przyszłe losowania"
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

struct MenuButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .fontWeight(.semibold)
            Spacer()
            Image(systemName: "chevron.right")
        }
        .padding()
        .background(Color.blue)
        .foregroundStyle(.white)
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
