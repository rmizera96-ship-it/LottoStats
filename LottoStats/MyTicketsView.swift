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
                    viewModel.addCurrentLineToDraft()
                } label: {
                    HStack {
                        Image(systemName: "plus.square.fill")
                        Text("Dodaj zestaw do kuponu")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
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
                
                draftLinesSection
                
                Button {
                    viewModel.saveTicket()
                } label: {
                    HStack {
                        Image(systemName: "ticket.fill")
                        Text("Zapisz kupon")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                ticketsFilterSection
                
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
            
            Text("Jeden kupon może zawierać kilka zestawów liczb, tak jak na prawdziwym kuponie Lotto.")
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
                
                Text("Wszystkie zestawy z tego kuponu będą sprawdzane dla tych samych losowań.")
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
                    
                    Text("Te same zestawy liczb wezmą udział także w osobnym losowaniu Plus.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var draftLinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Zestawy na tym kuponie")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.draftLines.isEmpty {
                    Button("Wyczyść") {
                        viewModel.clearDraftLines()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            
            if viewModel.draftLines.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nie dodano jeszcze żadnego zestawu.")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Wpisz liczby i kliknij „Dodaj zestaw do kuponu”. Możesz też od razu kliknąć „Zapisz kupon” — aktualnie wpisane liczby zostaną zapisane jako pierwszy zestaw.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(Array(viewModel.draftLines.enumerated()), id: \.element.id) { index, line in
                    DraftLineRow(
                        index: index,
                        line: line
                    ) {
                        viewModel.removeDraftLine(line)
                    }
                }
            }
        }
    }
    
    private var ticketsFilterSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Filtrowanie kuponów")
                            .font(.headline)
                        
                        Text("Pokazano \(viewModel.filteredTicketsCount) z \(viewModel.tickets.count) kuponów")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Picker("Status", selection: $viewModel.selectedStatusFilter) {
                        ForEach(TicketStatusFilter.allCases) { filter in
                            Text(filter.displayName)
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gra")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Picker("Gra", selection: $viewModel.selectedGameFilter) {
                        ForEach(TicketGameFilter.allCases) { filter in
                            Text(filter.displayName)
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            } else if viewModel.filteredTickets.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Brak kuponów dla wybranego filtra")
                            .font(.headline)
                        
                        Text("Zmień filtr statusu albo gry, żeby zobaczyć inne kupony.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(viewModel.filteredTickets) { ticket in
                    VStack(spacing: 8) {
                        TicketRow(
                            ticket: ticket,
                            checkResult: viewModel.checkResult(for: ticket)
                        ) {
                            viewModel.requestDelete(ticket)
                        }
                        
                        NavigationLink {
                            TicketDetailView(
                                ticket: ticket,
                                checkResult: viewModel.checkResult(for: ticket)
                            )
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("Pokaż szczegóły")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
        }
    }
}

struct DraftLineRow: View {
    let index: Int
    let line: TicketLine
    let onDelete: () -> Void
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Zestaw \(index + 1)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                
                HStack {
                    ForEach(line.numbers, id: \.self) { number in
                        NumberBall(number: number, style: .lotto, size: 34)
                    }
                }
                
                if !line.extraNumbers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Euroliczby")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            ForEach(line.extraNumbers, id: \.self) { number in
                                NumberBall(number: number, style: .plus, size: 34)
                            }
                        }
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
    
    private var hasExtraNumbers: Bool {
        ticket.lines.contains { !$0.extraNumbers.isEmpty }
    }
    
    private var isForToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        
        return ticket.drawDates.contains { drawDate in
            Calendar.current.isDate(
                Calendar.current.startOfDay(for: drawDate),
                inSameDayAs: today
            )
        }
    }
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                topSection
                
                badgesSection
                
                ForEach(Array(ticket.lines.enumerated()), id: \.element.id) { index, line in
                    ticketLineSection(index: index, line: line)
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
            
            Text("\(ticket.lines.count) zest.")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
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
            
            if isForToday {
                Text("Dzisiaj")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            if hasExtraNumbers {
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
    
    private func ticketLineSection(index: Int, line: TicketLine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if ticket.lines.count > 1 {
                Text("Zestaw \(index + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                ForEach(line.numbers, id: \.self) { number in
                    NumberBall(
                        number: number,
                        style: mainNumberStyle(number, line: line),
                        size: 34
                    )
                }
            }
            
            if !line.extraNumbers.isEmpty {
                HStack {
                    ForEach(line.extraNumbers, id: \.self) { number in
                        NumberBall(
                            number: number,
                            style: extraNumberStyle(number, line: line),
                            size: 34
                        )
                    }
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
    
    private func mainNumberStyle(_ number: Int, line: TicketLine) -> NumberBallStyle {
        if checkResult.isNumberMatched(number, in: line) {
            return .matched
        }
        
        if checkResult.checkedDraws.isEmpty {
            return .lotto
        }
        
        return .inactive
    }
    
    private func extraNumberStyle(_ number: Int, line: TicketLine) -> NumberBallStyle {
        if checkResult.isExtraNumberMatched(number, in: line) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text(check.drawDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .fontWeight(.semibold)
            
            ForEach(check.lineResults) { lineResult in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zestaw \(lineResult.lineIndex + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("Liczby główne: \(resultText(for: lineResult.lottoMatchedNumbers.count))")
                        .font(.caption)
                    
                    Text("Trafione główne: \(numbersText(lineResult.lottoMatchedNumbers))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !lineResult.line.extraNumbers.isEmpty {
                        if check.hasExtraResult {
                            Text("Euroliczby: \(resultText(for: lineResult.extraMatchedNumbers.count))")
                                .font(.caption)
                            
                            Text("Trafione euroliczby: \(numbersText(lineResult.extraMatchedNumbers))")
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
                            Text("Lotto Plus: \(resultText(for: lineResult.plusMatchedNumbers.count))")
                                .font(.caption)
                            
                            Text("Trafione Plus: \(numbersText(lineResult.plusMatchedNumbers))")
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
