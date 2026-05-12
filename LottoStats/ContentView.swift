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
    @State private var selectedGame: LottoGame = .lotto
    
    let tickets: [LottoTicket]
    
    private let repository = LottoRepository.shared
    
    private var games: [LottoGame] {
        repository.availableGames()
    }
    
    private var latestDraw: DrawResult? {
        repository.latestDraw(for: selectedGame)
    }
    
    private var selectedGameDraws: [DrawResult] {
        repository.draws(for: selectedGame)
    }
    
    private var mostFrequentNumberText: String {
        let mostFrequent = NumberFrequency.calculate(from: selectedGameDraws).first
        return mostFrequent.map { "\($0.number)" } ?? "-"
    }
    
    private var activeTicketsCount: Int {
        tickets.filter { ticket in
            ticket.drawDates.contains { drawDate in
                let today = Calendar.current.startOfDay(for: Date())
                let drawDay = Calendar.current.startOfDay(for: drawDate)
                let hasResult = repository.result(
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
                repository.result(
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
                    ForEach(games) { game in
                        Text(game.displayName)
                            .tag(game)
                    }
                }
                .pickerStyle(.segmented)
                
                latestDrawCard
                
                VStack(spacing: 12) {
                    InfoCard(
                        title: "Najczęstsza liczba",
                        value: mostFrequentNumberText,
                        subtitle: "Na podstawie historii wybranej gry"
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
                
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Warstwa danych")
                            .font(.headline)
                        
                        Text("Wyniki są teraz pobierane przez LottoRepository. Na razie zwraca dane testowe, ale później podmienimy je na API.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
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
        AppCard {
            if let latestDraw {
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
                            NumberBall(number: number, style: .lotto)
                        }
                    }
                    
                    if let plusNumbers = latestDraw.plusNumbers,
                       selectedGame.supportsPlus {
                        Divider()
                        
                        Text("Lotto Plus")
                            .font(.headline)
                        
                        HStack {
                            ForEach(plusNumbers, id: \.self) { number in
                                NumberBall(number: number, style: .plus)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brak danych")
                        .font(.headline)
                    
                    Text("Dla gry \(selectedGame.displayName) nie mamy jeszcze przykładowych wyników.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
