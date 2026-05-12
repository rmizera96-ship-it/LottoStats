import SwiftUI

struct MyTicketsView: View {
    @Binding var tickets: [LottoTicket]
    
    @State private var numberInputs = Array(repeating: "", count: 6)
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let latestDraw = DrawResult.sample
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
                latestDrawSection
                
                inputSection
                
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
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dodaj własny kupon")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Wpisz 6 liczb od 1 do 49 albo wylosuj je automatycznie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var latestDrawSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ostatnie losowanie")
                .font(.headline)
            
            Text(latestDraw.drawDate.formatted(date: .long, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                ForEach(latestDraw.numbers, id: \.self) { number in
                    Text("\(number)")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            
            Text("Te liczby będą porównywane z Twoimi kuponami.")
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
                    TicketRow(ticket: ticket, latestDraw: latestDraw)
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
        let newTicket = LottoTicket(numbers: sortedNumbers)
        
        tickets.insert(newTicket, at: 0)
        numberInputs = Array(repeating: "", count: 6)
        errorMessage = nil
        successMessage = "Kupon został dodany."
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
}

struct TicketRow: View {
    let ticket: LottoTicket
    let latestDraw: DrawResult
    
    private var matchedNumbers: [Int] {
        let winningNumbers = Set(latestDraw.numbers)
        return ticket.numbers.filter { winningNumbers.contains($0) }
    }
    
    private var resultText: String {
        switch matchedNumbers.count {
        case 0:
            return "Brak trafień"
        case 1:
            return "1 trafienie"
        case 2...4:
            return "\(matchedNumbers.count) trafienia"
        default:
            return "\(matchedNumbers.count) trafień"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.createdAt.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(resultText)
                        .font(.headline)
                }
                
                Spacer()
                
                Text("\(matchedNumbers.count)/6")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            HStack {
                ForEach(ticket.numbers, id: \.self) { number in
                    Text("\(number)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 34, height: 34)
                        .background(isMatched(number) ? Color.green.opacity(0.3) : Color.blue.opacity(0.15))
                        .clipShape(Circle())
                }
            }
            
            if !matchedNumbers.isEmpty {
                Text("Trafione: \(matchedNumbers.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func isMatched(_ number: Int) -> Bool {
        latestDraw.numbers.contains(number)
    }
}

#Preview {
    NavigationStack {
        MyTicketsView(tickets: .constant([
            LottoTicket(numbers: [3, 12, 19, 25, 34, 47]),
            LottoTicket(numbers: [1, 2, 3, 4, 5, 6])
        ]))
    }
}
