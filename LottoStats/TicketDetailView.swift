import SwiftUI

struct TicketDetailView: View {
    let ticket: LottoTicket
    let checkResult: TicketCheckResult
    let winningsSummary: TicketWinningsSummary
    let isLoadingWinnings: Bool

    init(
        ticket: LottoTicket,
        checkResult: TicketCheckResult,
        winningsSummary: TicketWinningsSummary? = nil,
        isLoadingWinnings: Bool = false
    ) {
        self.ticket = ticket
        self.checkResult = checkResult
        self.winningsSummary = winningsSummary ?? TicketWinningsSummary(
            wins: [],
            checkedDrawsCount: checkResult.checkedDrawsCount,
            loadedDrawsCount: 0
        )
        self.isLoadingWinnings = isLoadingWinnings
    }
    
    private var dateRangeText: String {
        let sortedDates = ticket.drawDates.sorted()
        
        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else {
            return "Brak dat losowań"
        }
        
        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            return AppFormatters.polishLongDate.string(from: firstDate)
        }
        
        return "\(AppFormatters.polishLongDate.string(from: firstDate)) - \(AppFormatters.polishLongDate.string(from: lastDate))"
    }
    
    private var bestMainHit: Int {
        checkResult.checkedDraws
            .flatMap { $0.lineResults }
            .map { $0.lottoMatchedNumbers.count }
            .max() ?? 0
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
            .safeAreaPadding(.bottom, 30)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Szczegóły kuponu")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        ScreenHeader(
            title: ticket.gameName,
            subtitle: "Szczegóły zapisanego kuponu i wyniki sprawdzania.",
            icon: ticket.game.symbolName,
            tint: ticket.game.visualColor
        )
    }
    
    private var ticketInfoSection: some View {
        AppCard(tint: ticket.game.visualColor) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Informacje o kuponie",
                    subtitle: "Status i przypisane losowania",
                    icon: "ticket.fill",
                    tint: ticket.game.visualColor
                )
                
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
                        .background(ticket.game.visualColor.opacity(0.15))
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
                    
                    Text(AppFormatters.polishDateTime.string(from: ticket.createdAt))
                        .font(.subheadline)
                }
            }
        }
    }
    
    private var ticketLinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Zestawy liczb",
                subtitle: "\(ticket.lines.count) zapisanych zestawów",
                icon: "list.number",
                tint: ticket.game.visualColor
            )
            
            ForEach(Array(ticket.lines.enumerated()), id: \.element.id) { index, line in
                AppCard(tint: ticket.game.visualColor) {
                    VStack(alignment: .leading, spacing: 10) {
                        CardHeader(
                            title: "Zestaw \(index + 1)",
                            subtitle: "Zapisane liczby kuponu",
                            icon: "number.square.fill",
                            tint: ticket.game.visualColor
                        )
                        
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
            SectionHeader(
                title: "Wyniki sprawdzania",
                subtitle: "Porównanie kuponu z wynikami losowań",
                icon: "checkmark.circle.fill",
                tint: .green
            )
            
            if checkResult.checkedDraws.isEmpty {
                EmptyStateCard(
                    title: "Kupon czeka na losowanie",
                    message: "Wyniki pojawią się tutaj automatycznie po przypisanym losowaniu.",
                    icon: "clock.fill",
                    tint: .orange
                )
            } else {
                AppCard(tint: .green) {
                    VStack(alignment: .leading, spacing: 14) {
                        CardHeader(
                            title: "Sprawdzone losowania",
                            subtitle: "\(checkResult.checkedDrawsCount) z \(checkResult.totalDrawsCount) wyników jest już dostępnych",
                            icon: "checkmark.seal.fill",
                            tint: .green
                        ) {
                            if winningsSummary.hasAnyWin {
                                CelebrationBadge(
                                    text: AppFormatters.currency(winningsSummary.totalAmount),
                                    tint: .green
                                )
                            } else if bestMainHit >= 3 {
                                CelebrationBadge(
                                    text: "\(bestMainHit) trafienia",
                                    tint: .green
                                )
                            }
                        }

                        winningsOverview
                    }
                }
                
                ForEach(checkResult.checkedDraws) { drawCheck in
                    TicketDrawDetailCard(
                        ticket: ticket,
                        check: drawCheck,
                        wins: winningsSummary.wins(for: drawCheck.drawDate),
                        isWinningsComplete: winningsSummary.isComplete
                    )
                }
            }
        }
    }
    

    @ViewBuilder
    private var winningsOverview: some View {
        if winningsSummary.isComplete {
            HStack(spacing: 12) {
                Image(systemName: winningsSummary.hasAnyWin ? "banknote.fill" : "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(winningsSummary.hasAnyWin ? Color.green : Color.secondary)
                    .frame(width: 38, height: 38)
                    .background(
                        (winningsSummary.hasAnyWin ? Color.green : Color.secondary)
                            .opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(winningsTitle)
                        .font(.subheadline.weight(.semibold))

                    Text(winningsSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.green.opacity(winningsSummary.hasAnyWin ? 0.09 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if isLoadingWinnings {
            HStack(spacing: 10) {
                ProgressView()
                Text("Pobieranie kwot wygranych...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("Kwoty wygranych są chwilowo niedostępne.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }


    private var winningsTitle: String {
        if winningsSummary.hasAnyWin {
            return checkResult.status == .checked ? "Łączna wygrana" : "Dotychczasowa wygrana"
        }

        return checkResult.status == .checked
            ? "Brak wygranej pieniężnej"
            : "Dotychczas brak wygranej pieniężnej"
    }

    private var winningsSubtitle: String {
        if winningsSummary.hasAnyWin {
            return AppFormatters.currency(winningsSummary.totalAmount)
        }

        return checkResult.status == .checked
            ? "Żaden zestaw nie osiągnął płatnego stopnia wygranej."
            : "Pozostałe losowania nadal mogą przynieść wygraną."
    }

    private var statusBackground: Color {
        switch checkResult.status {
        case .checked:
            return Color.green.opacity(0.2)
        case .partiallyChecked:
            return Color.orange.opacity(0.2)
        case .active:
            return ticket.game.visualColor.opacity(0.2)
        case .waitingForResults:
            return Color.orange.opacity(0.2)
        }
    }
    
    private func numberStyle(_ number: Int, line: TicketLine) -> NumberBallStyle {
        if checkResult.isNumberMatched(number, in: line) {
            return .matched
        }
        
        if checkResult.checkedDraws.isEmpty {
            return ticket.game.ballStyle
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
    let wins: [TicketPrizeWin]
    let isWinningsComplete: Bool
    
    var body: some View {
        AppCard(tint: ticket.game.visualColor) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    title: AppFormatters.polishLongDate.string(from: check.drawDate),
                    subtitle: "Wyniki zestawów z tego losowania",
                    icon: "calendar.badge.checkmark",
                    tint: ticket.game.visualColor
                )
                
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

                        let lineWins = wins.filter { $0.lineIndex == lineResult.lineIndex }

                        if !lineWins.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(lineWins) { win in
                                    HStack(spacing: 8) {
                                        Image(systemName: "banknote.fill")
                                            .foregroundStyle(.green)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(win.source.rawValue) • \(win.rankDisplayName)")
                                                .font(.caption.weight(.semibold))

                                            Text("Trafienie: \(win.matchDescription)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(AppFormatters.currency(win.amount))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.green)
                                    }
                                    .padding(10)
                                    .background(Color.green.opacity(0.09))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        } else if isWinningsComplete {
                            Text("Brak wygranej pieniężnej dla tego zestawu.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
