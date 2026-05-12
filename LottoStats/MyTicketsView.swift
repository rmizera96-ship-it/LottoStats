import SwiftUI

struct MyTicketsView: View {
    @Binding var tickets: [LottoTicket]
    
    @State private var numberInputs = Array(repeating: "", count: 6)
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
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
                    TicketRow(ticket: ticket)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ticket.createdAt.formatted(date: .long, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                ForEach(ticket.numbers, id: \.self) { number in
                    Text("\(number)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 34, height: 34)
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

#Preview {
    NavigationStack {
        MyTicketsView(tickets: .constant([]))
    }
}//
//  MyTicketView.swift
//  LottoStats
//
//  Created by Rafal Mizera on 12/05/2026.
//

