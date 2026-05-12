import SwiftUI

struct MyTicketsView: View {
    @Binding var tickets: [LottoTicket]
    
    @State private var numberInputs = Array(repeating: "", count: 6)
    @State private var includesPlus = false
    @State private var selectedDrawCount = 1
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var ticketToDelete: LottoTicket?
    @State private var showDeleteAlert = false
    
    private let gameName = "Lotto"
    private let drawCountOptions = [1, 2, 4, 8, 10]
    
    private var selectedDrawDates: [Date] {
        DrawResult.upcomingDrawDates(count: selectedDrawCount)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
                selectedDrawSection
                
                drawCountSection
                
                inputSection
                
                plusSection
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                if let successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                
                Button {
                    saveTicket()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Dodaj kupon")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Button {
                    generateRandomTicket()
                } label: {
                    HStack {
                        Image(systemName: "dice.fill")
                        Text("Wylosuj liczby")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                ticketsSection
            }
            .padding()
        }
        .navigationTitle("Moje kupony")
        .alert("Usunąć kupon?", isPresented: $showDeleteAlert) {
            Button("Usuń", role: .destructive) {
                if let ticketToDelete {
                    deleteTicket(ticketToDelete)
                }
            }
            
            Button("Anuluj", role: .cancel) {
                ticketToDelete = nil
            }
        } message: {
            Text("Tego działania nie można cofnąć.")
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dodaj własny kupon")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Kupon może być przypisany do jednego albo kilku kolejnych losowań.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var selectedDrawSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kupon na losowanie")
                    .font(.headline)
                
                Text(gameName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let firstDate = selectedDrawDates.first,
                   let lastDate = selectedDrawDates.last {
                    Text("\(firstDate.formatted(date: .long, time: .omitted)) - \(lastDate.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Liczba losowań: \(selectedDrawCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("Kupon będzie sprawdzany tylko z wynikami przypisanych losowań.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var drawCountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Liczba kolejnych losowań")
                .font(.headline)
            
            Picker("Liczba losowań", selection: $selectedDrawCount) {
                ForEach(drawCountOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Twoje liczby")
                .font(.headline)
            
            HStack {
                ForEach(numberInputs.indices, id: \.self) { index in
                    TextField("\(index + 1)", text: $numberInputs[index])
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                        .frame(width: 46, height: 46)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private var plusSection: some View {
        AppCard {
            Toggle(isOn: $includesPlus) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lotto Plus")
                        .font(.headline)
                    
                    Text("Te same liczby wezmą udział także w osobnym losowaniu Plus.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var ticketsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zapisane kupony")
                .font(.headline)
            
            if tickets.isEmpty {
                AppCard {
                    Text("Nie masz jeszcze zapisanych kuponów.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(tickets) { ticket in
                    TicketRow(ticket: ticket) {
                        requestDelete(ticket)
                    }
                }
            }
        }
    }
    
    private func saveTicket() {
        let numbers = numberInputs.compactMap { input in
            Int(input.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        guard numbers.count == 6 else {
            errorMessage = "Wpisz dokładnie 6 liczb."
            successMessage = nil
            return
        }
        
        guard numbers.allSatisfy({ number in
            number >= 1 && number <= 49
        }) else {
            errorMessage = "Każda liczba musi być z zakresu od 1 do 49."
            successMessage = nil
            return
        }
        
        guard Set(numbers).count == 6 else {
            errorMessage = "Liczby nie mogą się powtarzać."
            successMessage = nil
            return
        }
        
        guard let firstDrawDate = selectedDrawDates.first else {
            errorMessage = "Nie udało się ustalić daty losowania."
            successMessage = nil
            return
        }
        
        let sortedNumbers = numbers.sorted()
        
        let newTicket = LottoTicket(
            gameName: gameName,
            numbers: sortedNumbers,
            drawDate: firstDrawDate,
            drawDates: selectedDrawDates,
            includesPlus: includesPlus
        )
        
        tickets.insert(newTicket, at: 0)
        numberInputs = Array(repeating: "", count: 6)
        includesPlus = false
        selectedDrawCount = 1
        errorMessage = nil
        successMessage = "Kupon został dodany na \(selectedDrawDates.count) losowanie/losowań."
    }
    
    private func generateRandomTicket() {
        let randomNumbers = Array(1...49)
            .shuffled()
            .prefix(6)
            .sorted()
        
        numberInputs = randomNumbers.map { String($0) }
        errorMessage = nil
        successMessage = nil
    }
    
    private func requestDelete(_ ticket: LottoTicket) {
        ticketToDelete = ticket
        showDeleteAlert = true
    }
    
    private func deleteTicket(_ ticket: LottoTicket) {
        tickets.removeAll { $0.id == ticket.id }
        ticketToDelete = nil
        errorMessage = nil
        successMessage = "Kupon został usunięty."
    }
}

struct TicketRow: View {
    let ticket: LottoTicket
    let onDelete: () -> Void
    
    private var matchingResults: [DrawResult] {
        ticket.drawDates.compactMap { drawDate in
            DrawResult.result(for: ticket.gameName, drawDate: drawDate)
        }
    }
    
    private var checkedDrawsCount: Int {
        matchingResults.count
    }
    
    private var statusText: String {
        if checkedDrawsCount == ticket.drawDates.count {
            return "Sprawdzony"
        }
        
        if checkedDrawsCount > 0 {
            return "Częściowo sprawdzony"
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let hasFutureDraw = ticket.drawDates.contains { drawDate in
            Calendar.current.startOfDay(for: drawDate) >= today
        }
        
        if hasFutureDraw {
            return "Aktywny"
        } else {
            return "Oczekuje na wyniki"
        }
    }
    
    private var dateRangeText: String {
        let sortedDates = ticket.drawDates.sorted()
        
        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else {
            return "Brak dat losowań"
        }
        
        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            return firstDate.formatted(date: .long, time: .omitted)
        }
        
        return "\(firstDate.formatted(date: .abbreviated, time: .omitted)) - \(lastDate.formatted(date: .abbreviated, time: .omitted))"
    }
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                topSection
                
                HStack {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusBackground)
                        .clipShape(Capsule())
                    
                    Text("\(ticket.drawDates.count) los.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                    
                    if ticket.includesPlus {
                        Text("Plus")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                
                numbersSection
                
                resultSection
            }
        }
    }
    
    private var topSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.gameName)
                    .font(.headline)
                
                Text("Losowania: \(dateRangeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Dodano: \(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    private var numbersSection: some View {
        HStack {
            ForEach(ticket.numbers, id: \.self) { number in
                NumberBall(
                    number: number,
                    style: numberStyle(number),
                    size: 34
                )
            }
        }
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if matchingResults.isEmpty {
                Text("Kupon nie został jeszcze sprawdzony.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Wyniki pojawią się po losowaniu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sprawdzone losowania: \(checkedDrawsCount)/\(ticket.drawDates.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(matchingResults) { result in
                    DrawCheckRow(ticket: ticket, result: result)
                }
            }
        }
    }
    
    private var statusBackground: Color {
        if checkedDrawsCount == ticket.drawDates.count {
            return Color.green.opacity(0.2)
        }
        
        if checkedDrawsCount > 0 {
            return Color.orange.opacity(0.2)
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let hasFutureDraw = ticket.drawDates.contains { drawDate in
            Calendar.current.startOfDay(for: drawDate) >= today
        }
        
        if hasFutureDraw {
            return Color.blue.opacity(0.2)
        } else {
            return Color.orange.opacity(0.2)
        }
    }
    
    private func numberStyle(_ number: Int) -> NumberBallStyle {
        let isMatchedInAnyDraw = matchingResults.contains { result in
            result.numbers.contains(number) ||
            (ticket.includesPlus && (result.plusNumbers?.contains(number) ?? false))
        }
        
        if isMatchedInAnyDraw {
            return .matched
        } else if matchingResults.isEmpty {
            return .lotto
        } else {
            return .inactive
        }
    }
}

struct DrawCheckRow: View {
    let ticket: LottoTicket
    let result: DrawResult
    
    private var lottoMatchedNumbers: [Int] {
        let winningNumbers = Set(result.numbers)
        return ticket.numbers.filter { winningNumbers.contains($0) }
    }
    
    private var plusMatchedNumbers: [Int] {
        guard let plusNumbers = result.plusNumbers else {
            return []
        }
        
        let winningNumbers = Set(plusNumbers)
        return ticket.numbers.filter { winningNumbers.contains($0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.drawDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("Lotto: \(resultText(for: lottoMatchedNumbers.count))")
                .font(.caption)
            
            Text("Trafione Lotto: \(lottoMatchedNumbers.isEmpty ? "brak" : lottoMatchedNumbers.map(String.init).joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if ticket.includesPlus {
                Text("Lotto Plus: \(resultText(for: plusMatchedNumbers.count))")
                    .font(.caption)
                
                Text("Trafione Plus: \(plusMatchedNumbers.isEmpty ? "brak" : plusMatchedNumbers.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
    
    private func resultText(for count: Int) -> String {
        switch count {
        case 0:
            return "brak trafień"
        case 1:
            return "1 trafienie"
        case 2...4:
            return "\(count) trafienia"
        default:
            return "\(count) trafień"
        }
    }
}

#Preview {
    NavigationStack {
        MyTicketsView(tickets: .constant([
            LottoTicket(
                gameName: "Lotto",
                numbers: [3, 12, 19, 25, 34, 47],
                drawDate: DrawResult.sample.drawDate,
                drawDates: [
                    DrawResult.samples[0].drawDate,
                    DrawResult.samples[1].drawDate
                ],
                includesPlus: true
            ),
            LottoTicket(
                gameName: "Lotto",
                numbers: [1, 2, 3, 4, 5, 6],
                drawDate: DrawResult.nextDrawDate,
                drawDates: DrawResult.upcomingDrawDates(count: 4),
                includesPlus: false
            )
        ]))
    }
}
