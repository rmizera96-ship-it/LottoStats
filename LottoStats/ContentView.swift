import SwiftUI

struct ContentView: View {
    @StateObject private var ticketViewModel = TicketViewModel()
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeView(tickets: ticketViewModel.tickets)
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
                MyTicketsView(viewModel: ticketViewModel)
            }
            .tabItem {
                Label("Kupony", systemImage: "ticket.fill")
            }
            
            NavigationStack {
                SettingsView(ticketViewModel: ticketViewModel)
            }
            .tabItem {
                Label("Ustawienia", systemImage: "gearshape.fill")
            }
        }
    }
}

struct HomeView: View {
    @StateObject private var viewModel = LottoDataViewModel()
    
    let tickets: [LottoTicket]
    
    private let repository = LottoRepository.shared
    
    private var games: [LottoGame] {
        repository.availableGames()
    }
    
    private var selectedGameBinding: Binding<LottoGame> {
        Binding {
            viewModel.selectedGame
        } set: { game in
            Task {
                await viewModel.selectGame(game)
            }
        }
    }
    
    private var mostFrequentNumberText: String {
        let mostFrequent = NumberFrequency.calculate(from: viewModel.draws).first
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
                
                Picker("Gra", selection: selectedGameBinding) {
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
                        Text("Źródło danych")
                            .font(.headline)
                        
                        Text(viewModel.dataSourceName)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Jeżeli w Secrets.plist jest poprawny klucz API, aplikacja używa prawdziwego API LOTTO. W przeciwnym razie działa na danych testowych.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Odśwież dane")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("LottoStats")
        .task {
            await viewModel.loadInitialData()
        }
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
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    
                    Text("Ładowanie danych...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let latestDraw = viewModel.latestDraw {
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
                       viewModel.selectedGame.supportsPlus {
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
                    
                    Text(viewModel.errorMessage ?? "Nie udało się pobrać danych.")
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
