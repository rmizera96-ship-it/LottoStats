import SwiftUI

struct MyTicketsView: View {
    @Binding var tickets: [LottoTicket]
    
    @State private var numberInputs = Array(repeating: "", count: 6)
    @State private var includesPlus = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var ticketToDelete: LottoTicket?
    @State private var showDeleteAlert = false
    
    private let gameName = "Lotto"
    private let selectedDrawDate = DrawResult.nextDrawDate
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
                selectedDrawSection
                
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
            
            Text("Kupon zostanie przypisany do konkretnego losowania.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var selectedDrawSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kupon na losowanie")
                .font(.headline)
            
            Text(gameName)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(selectedDrawDate.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Po tym losowaniu kupon zostanie sprawdzony tylko z wynikiem z tej daty.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        VStack(alignment: .leading, spacing: 8) {
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
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var ticketsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zapisane kupony")
                .font(.headline)
            
            if tickets.isEmpty {
                Text("Nie masz jeszcze zapisanych kuponów.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
        
        let sortedNumbers = numbers.sorted()
        
        let newTicket = LottoTicket(
            gameName: gameName,
            numbers: sortedNumbers,
            drawDate: selectedDrawDate,
            includesPlus: includesPlus
        )
        
        tickets.insert(newTicket, at: 0)
        numberInputs = Array(repeating: "", count: 6)
        includesPlus = false
        errorMessage = nil
        successMessage = "Kupon został dodany na konkretne losowanie."
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
    
    private var matchingResult: DrawResult? {
        DrawResult.result(for: ticket.gameName, drawDate: ticket.drawDate)
    }
    
    private var lottoMatchedNumbers: [Int] {
        guard let matchingResult else {
            return []
        }
        
        let winningNumbers = Set(matchingResult.numbers)
        return ticket.numbers.filter { winningNumbers.contains($0) }
    }
    
    private var plusMatchedNumbers: [Int] {
        guard let plusNumbers = matchingResult?.plusNumbers else {
            return []
        }
        
        let winningNumbers = Set(plusNumbers)
        return ticket.numbers.filter { winningNumbers.contains($0) }
    }
    
    private var statusText: String {
        if matchingResult != nil {
            return "Sprawdzony"
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let drawDay = Calendar.current.startOfDay(for: ticket.drawDate)
        
        if drawDay >= today {
            return "Aktywny"
        } else {
            return "Oczekuje na wynik"
        }
    }
    
    private var lottoResultText: String {
        guard matchingResult != nil else {
            return "Kupon nie został jeszcze sprawdzony"
        }
        
        return resultText(for: lottoMatchedNumbers.count)
    }
    
    private var plusResultText: String {
        guard ticket.includesPlus else {
            return "Lotto Plus nie było zaznaczone"
        }
        
        guard matchingResult?.plusNumbers != nil else {
            return "Brak wyniku Lotto Plus dla tego losowania"
        }
        
        return resultText(for: plusMatchedNumbers.count)
    }
    
    var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var topSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.gameName)
                    .font(.headline)
                
                Text("Losowanie: \(ticket.drawDate.formatted(date: .long, time: .omitted))")
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
                Text("\(number)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(width: 34, height: 34)
                    .background(numberBackground(number))
                    .clipShape(Circle())
            }
        }
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lotto: \(lottoResultText)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if matchingResult != nil {
                Text("Trafione Lotto: \(lottoMatchedNumbers.isEmpty ? "brak" : lottoMatchedNumbers.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if ticket.includesPlus {
                Divider()
                
                Text("Lotto Plus: \(plusResultText)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if matchingResult?.plusNumbers != nil {
                    Text("Trafione Plus: \(plusMatchedNumbers.isEmpty ? "brak" : plusMatchedNumbers.map(String.init).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var statusBackground: Color {
        if matchingResult != nil {
            return Color.green.opacity(0.2)
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let drawDay = Calendar.current.startOfDay(for: ticket.drawDate)
        
        if drawDay >= today {
            return Color.blue.opacity(0.2)
        } else {
            return Color.orange.opacity(0.2)
        }
    }
    
    private func numberBackground(_ number: Int) -> Color {
        guard matchingResult != nil else {
            return Color.blue.opacity(0.15)
        }
        
        if lottoMatchedNumbers.contains(number) || plusMatchedNumbers.contains(number) {
            return Color.green.opacity(0.3)
        } else {
            return Color.gray.opacity(0.15)
        }
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
                includesPlus: true
            ),
            LottoTicket(
                gameName: "Lotto",
                numbers: [1, 2, 3, 4, 5, 6],
                drawDate: DrawResult.nextDrawDate,
                includesPlus: false
            )
        ]))
    }
}
