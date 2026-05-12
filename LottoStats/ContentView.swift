import SwiftUI

struct ContentView: View {
    @State private var tickets: [LottoTicket] = []
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeView(tickets: tickets)
            }
            .tabItem {
                Label("Start", systemImage: "house.fill")
            }
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Historia", systemImage: "clock.arrow.circlepath")
            }
            
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statystyki", systemImage: "chart.bar.xaxis")
            }
            
            NavigationStack {
                MyTicketsView(tickets: $tickets)
            }
            .tabItem {
                Label("Kupony", systemImage: "ticket.fill")
            }
        }
        .onAppear {
            tickets = TicketStorage.load()
        }
        .onChange(of: tickets) { _, newTickets in
            TicketStorage.save(newTickets)
        }
    }
}

struct HomeView: View {
    @State private var selectedGame = "Lotto"
    
    let tickets: [LottoTicket]
    let games = ["Lotto", "Mini Lotto", "Eurojackpot"]
    let latestDraw = DrawResult.sample
    
    private var mostFrequentNumberText: String {
        let mostFrequent = NumberFrequency.calculate(from: DrawResult.samples).first
        return mostFrequent.map { "\($0.number)" } ?? "-"
    }
    
    private var activeTicketsCount: Int {
        tickets.filter { ticket in
            ticket.drawDates.contains { drawDate in
                let today = Calendar.current.startOfDay(for: Date())
                let drawDay = Calendar.current.startOfDay(for: drawDate)
                let hasResult = DrawResult.result(
                    for: ticket.gameName,
                    drawDate: drawDate
                ) != nil
                
                return drawDay >= today && !hasResult
            }
        }.count
    }
    
    private var checkedTicketsCount: Int {
        tickets.filter { ticket in
            ticket.drawDates.contains { drawDate in
                DrawResult.result(
                    for: ticket.gameName,
                    drawDate: drawDate
                ) != nil
            }
        }.count
    }
    
    private var plusTicketsCount: Int {
        tickets.filter { $0.includesPlus }.count
    }
    
    var body: some View {
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
                    
                    InfoCard(
                        title: "Sprawdzone kupony",
                        value: "\(checkedTicketsCount)",
                        subtitle: "Kupony, dla których mamy wynik losowania"
                    )
                    
                    InfoCard(
                        title: "Kupony z Lotto Plus",
                        value: "\(plusTicketsCount)",
                        subtitle: "Kupony z zaznaczoną opcją Plus"
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nawigacja")
                        .font(.headline)
                    
                    Text("Użyj dolnego menu, żeby przejść do historii losowań, statystyk albo swoich kuponów.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("LottoStats")
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LottoStats")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Sprawdzaj wyniki losowań, statystyki liczb i swoje kupony.")
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
            
            if let plusNumbers = latestDraw.plusNumbers {
                Divider()
                
                Text("Lotto Plus")
                    .font(.headline)
                
                HStack {
                    ForEach(plusNumbers, id: \.self) { number in
                        Text("\(number)")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Circle())
                    }
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
