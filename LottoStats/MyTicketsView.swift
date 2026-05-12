import SwiftUI

struct MyTicketsView: View {
    @ObservedObject var viewModel: TicketViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerView
                
                gamePickerSection
                
                selectedDrawSection
                
                drawCountSection
                
                mainNumbersInputSection
                
                if viewModel.currentRules.extraNumbersCount > 0 {
                    extraNumbersInputSection
                }
                
                if viewModel.currentRules.supportsPlus {
                    plusSection
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                
                Button {
                    viewModel.saveTicket()
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
                    viewModel.generateRandomTicket()
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
        .alert("Usunąć kupon?", isPresented: $viewModel.showDeleteAlert) {
            Button("Usuń", role: .destructive) {
                viewModel.confirmDelete()
            }
            
            Button("Anuluj", role: .cancel) {
                viewModel.cancelDelete()
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
            
            Text("Wybierz grę, wpisz liczby i przypisz kupon do jednego albo kilku kolejnych losowań.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var gamePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gra")
                .font(.headline)
            
            Picker("Gra", selection: $viewModel.selectedGame) {
                ForEach(viewModel.availableGamesForTickets) { game in
                    Text(game.displayName)
                        .tag(game)
                }
            }
            .pickerStyle(.segmented)
            
            Text("Zasady: \(viewModel.currentRules.description)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var selectedDrawSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kupon na losowanie")
                    .font(.headline)
                
                Text(viewModel.selectedGame.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let firstDate = viewModel.selectedDrawDates.first,
                   let lastDate = viewModel.selectedDrawDates.last {
                    Text("\(firstDate.formatted(date: .long, time: .omitted)) - \(lastDate.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Brak dostępnych dat losowań dla tej gry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Liczba losowań: \(viewModel.selectedDrawCount)")
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
            
            Picker("Liczba losowań", selection: $viewModel.selectedDrawCount) {
                ForEach(viewModel.drawCountOptions, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var mainNumbersInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Liczby główne")
                .font(.headline)
            
            Text("Wybierz \(viewModel.currentRules.mainNumbersCount) liczb z zakresu \(viewModel.currentRules.mainNumberRange.lowerBound)-\(viewModel.currentRules.mainNumberRange.upperBound).")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                ForEach(viewModel.numberInputs.indices, id: \.self) { index in
                    TextField("\(index + 1)", text: $viewModel.numberInputs[index])
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
    
    private var extraNumbersInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Euroliczby")
                .font(.headline)
            
            if let extraRange = viewModel.currentRules.extraNumberRange {
                Text("Wybierz \(viewModel.currentRules.extraNumbersCount) euroliczby z zakresu \(extraRange.lowerBound)-\(extraRange.upperBound).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                ForEach(viewModel.extraNumberInputs.indices, id: \.self) { index in
                    TextField("\(index + 1)", text: $viewModel.extraNumberInputs[index])
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                        .frame(width: 46, height: 46)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private var plusSection: some View {
        AppCard {
            Toggle(isOn: $viewModel.includesPlus) {
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
            
            if viewModel.tickets.isEmpty {
                AppCard {
                    Text("Nie masz jeszcze zapisanych kuponów.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(viewModel.tickets) { ticket in
                    TicketRow(
                        ticket: ticket,
                        checkResult: viewModel.checkResult(for: ticket)
                    ) {
                        viewModel.requestDelete(ticket)
                    }
                }
            }
        }
    }
}

struct TicketRow: View {
    let ticket: LottoTicket
    let checkResult: TicketCheckResult
    let onDelete: () -> Void
    
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
                
                badgesSection
                
                mainNumbersSection
                
                if !ticket.extraNumbers.isEmpty {
                    extraNumbersSection
                }
                
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
    
    private var badgesSection: some View {
        HStack {
            Text(checkResult.status.displayName)
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
            
            if !ticket.extraNumbers.isEmpty {
                Text("Euroliczby")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
    }
    
    private var mainNumbersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Liczby główne")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack {
                ForEach(ticket.numbers, id: \.self) { number in
                    NumberBall(
                        number: number,
                        style: mainNumberStyle(number),
                        size: 34
                    )
                }
            }
        }
    }
    
    private var extraNumbersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Euroliczby")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack {
                ForEach(ticket.extraNumbers, id: \.self) { number in
                    NumberBall(
                        number: number,
                        style: extraNumberStyle(number),
                        size: 34
                    )
                }
            }
        }
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if checkResult.checkedDraws.isEmpty {
                Text("Kupon nie został jeszcze sprawdzony.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Wyniki pojawią się po losowaniu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sprawdzone losowania: \(checkResult.checkedDrawsCount)/\(checkResult.totalDrawsCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(checkResult.checkedDraws) { drawCheck in
                    DrawCheckRow(
                        ticket: ticket,
                        check: drawCheck
                    )
                }
            }
        }
    }
    
    private var statusBackground: Color {
        switch checkResult.status {
        case .checked:
            return Color.green.opacity(0.2)
        case .partiallyChecked:
            return Color.orange.opacity(0.2)
        case .active:
            return Color.blue.opacity(0.2)
        case .waitingForResults:
            return Color.orange.opacity(0.2)
        }
    }
    
    private func mainNumberStyle(_ number: Int) -> NumberBallStyle {
        if checkResult.isNumberMatched(number) {
            return .matched
        }
        
        if checkResult.checkedDraws.isEmpty {
            return .lotto
        }
        
        return .inactive
    }
    
    private func extraNumberStyle(_ number: Int) -> NumberBallStyle {
        if checkResult.isExtraNumberMatched(number) {
            return .matched
        }
        
        if checkResult.checkedDraws.isEmpty {
            return .plus
        }
        
        return .inactive
    }
}

struct DrawCheckRow: View {
    let ticket: LottoTicket
    let check: SingleDrawCheckResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(check.drawDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("Liczby główne: \(resultText(for: check.lottoMatchedNumbers.count))")
                .font(.caption)
            
            Text("Trafione główne: \(numbersText(check.lottoMatchedNumbers))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if !ticket.extraNumbers.isEmpty {
                if check.hasExtraResult {
                    Text("Euroliczby: \(resultText(for: check.extraMatchedNumbers.count))")
                        .font(.caption)
                    
                    Text("Trafione euroliczby: \(numbersText(check.extraMatchedNumbers))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Euroliczby: brak wyniku")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if ticket.includesPlus {
                if check.hasPlusResult {
                    Text("Lotto Plus: \(resultText(for: check.plusMatchedNumbers.count))")
                        .font(.caption)
                    
                    Text("Trafione Plus: \(numbersText(check.plusMatchedNumbers))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Lotto Plus: brak wyniku")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }
    
    private func numbersText(_ numbers: [Int]) -> String {
        numbers.isEmpty ? "brak" : numbers.map(String.init).joined(separator: ", ")
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
    MyTicketsView(viewModel: TicketViewModel())
}
