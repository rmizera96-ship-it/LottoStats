import SwiftUI

struct TicketDetailView: View {
    let ticket: LottoTicket
    let checkResult: TicketCheckResult
    
    private var dateRangeText: String {
        let sortedDates = ticket.drawDates.sorted()
        
        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else {
            return "Brak dat losowań"
        }
        
        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            return firstDate.formatted(date: .long, time: .omitted)
        }
        
        return "\(firstDate.formatted(date: .long, time: .omitted)) - \(lastDate.formatted(date: .long, time: .omitted))"
    }
    
    private var hasExtraNumbers: Bool {
        ticket.lines.contains { !$0.extraNumbers.isEmpty }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerSection
                
                ticketInfoSection
                
                ticketLinesSection
                
                checkResultsSection
            }
            .padding()
        }
        .navigationTitle("Szczegóły kuponu")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ticket.gameName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Szczegóły zapisanego kuponu i wyniki sprawdzania.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var ticketInfoSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Informacje o kuponie")
                    .font(.headline)
                
                HStack {
                    Text(checkResult.status.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusBackground)
                        .clipShape(Capsule())
                    
                    Text("\(ticket.lines.count) zest.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground))
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
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Losowania")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(dateRangeText)
                        .font(.subheadline)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dodano")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(ticket.createdAt.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var ticketLinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zestawy liczb")
                .font(.headline)
            
            ForEach(Array(ticket.lines.enumerated()), id: \.element.id) { index, line in
                AppCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Zestaw \(index + 1)")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Liczby główne")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                ForEach(line.numbers, id: \.self) { number in
                                    NumberBall(
                                        number: number,
                                        style: numberStyle(number, line: line),
                                        size: 36
                                    )
                                }
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
                                        NumberBall(
                                            number: number,
                                            style: extraNumberStyle(number, line: line),
                                            size: 36
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var checkResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wyniki sprawdzania")
                .font(.headline)
            
            if checkResult.checkedDraws.isEmpty {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kupon nie został jeszcze sprawdzony.")
                            .font(.headline)
                        
                        Text("Wyniki pojawią się po przypisanym losowaniu.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sprawdzone losowania")
                            .font(.headline)
                        
                        Text("\(checkResult.checkedDrawsCount)/\(checkResult.totalDrawsCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                ForEach(checkResult.checkedDraws) { drawCheck in
                    TicketDrawDetailCard(
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
    
    private func numberStyle(_ number: Int, line: TicketLine) -> NumberBallStyle {
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

private struct TicketDrawDetailCard: View {
    let ticket: LottoTicket
    let check: SingleDrawCheckResult
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(check.drawDate.formatted(date: .long, time: .omitted))
                    .font(.headline)
                
                ForEach(check.lineResults) { lineResult in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zestaw \(lineResult.lineIndex + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        resultRow(
                            title: "Liczby główne",
                            matched: lineResult.lottoMatchedNumbers,
                            total: lineResult.line.numbers.count
                        )
                        
                        if !lineResult.line.extraNumbers.isEmpty {
                            if check.hasExtraResult {
                                resultRow(
                                    title: "Euroliczby",
                                    matched: lineResult.extraMatchedNumbers,
                                    total: lineResult.line.extraNumbers.count
                                )
                            } else {
                                Text("Euroliczby: brak wyniku")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if ticket.includesPlus {
                            if check.hasPlusResult {
                                resultRow(
                                    title: "Lotto Plus",
                                    matched: lineResult.plusMatchedNumbers,
                                    total: lineResult.line.numbers.count
                                )
                            } else {
                                Text("Lotto Plus: brak wyniku")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if lineResult.id != check.lineResults.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
    
    private func resultRow(
        title: String,
        matched: [Int],
        total: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(matched.count)/\(total)")
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("Trafione: \(matched.isEmpty ? "brak" : matched.map(String.init).joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        TicketDetailView(
            ticket: LottoTicket(
                gameName: "Eurojackpot",
                lines: [
                    TicketLine(numbers: [7, 14, 23, 36, 45], extraNumbers: [2, 11]),
                    TicketLine(numbers: [3, 18, 25, 34, 49], extraNumbers: [5, 9])
                ],
                drawDate: DrawResult.eurojackpotNextDrawDates.first ?? Date(),
                drawDates: DrawResult.upcomingDrawDates(for: .eurojackpot, count: 2)
            ),
            checkResult: TicketChecker().check(
                ticket: LottoTicket(
                    gameName: "Eurojackpot",
                    lines: [
                        TicketLine(numbers: [7, 14, 23, 36, 45], extraNumbers: [2, 11])
                    ],
                    drawDate: DrawResult.samples.first?.drawDate ?? Date(),
                    drawDates: [DrawResult.samples.first?.drawDate ?? Date()]
                )
            )
        )
    }
}
