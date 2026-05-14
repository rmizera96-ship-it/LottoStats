import Foundation

enum TicketStatus {
    case active
    case checked
    case partiallyChecked
    case waitingForResults
    
    var displayName: String {
        switch self {
        case .active:
            return "Aktywny"
        case .checked:
            return "Sprawdzony"
        case .partiallyChecked:
            return "Częściowo sprawdzony"
        case .waitingForResults:
            return "Oczekuje na wyniki"
        }
    }
}

struct TicketLineCheckResult: Identifiable {
    let line: TicketLine
    let lineIndex: Int
    let lottoMatchedNumbers: [Int]
    let plusMatchedNumbers: [Int]
    let extraMatchedNumbers: [Int]
    
    var id: UUID {
        line.id
    }
}

struct SingleDrawCheckResult: Identifiable {
    let id: Date
    let drawDate: Date
    let lineResults: [TicketLineCheckResult]
    let hasPlusResult: Bool
    let hasExtraResult: Bool
    
    var lottoMatchedNumbers: [Int] {
        Array(Set(lineResults.flatMap { $0.lottoMatchedNumbers })).sorted()
    }
    
    var plusMatchedNumbers: [Int] {
        Array(Set(lineResults.flatMap { $0.plusMatchedNumbers })).sorted()
    }
    
    var extraMatchedNumbers: [Int] {
        Array(Set(lineResults.flatMap { $0.extraMatchedNumbers })).sorted()
    }
    
    init(
        drawDate: Date,
        lineResults: [TicketLineCheckResult],
        hasPlusResult: Bool,
        hasExtraResult: Bool
    ) {
        self.id = drawDate
        self.drawDate = drawDate
        self.lineResults = lineResults
        self.hasPlusResult = hasPlusResult
        self.hasExtraResult = hasExtraResult
    }
}

struct TicketCheckResult {
    let status: TicketStatus
    let checkedDraws: [SingleDrawCheckResult]
    let totalDrawsCount: Int
    
    var checkedDrawsCount: Int {
        checkedDraws.count
    }
    
    func isNumberMatched(_ number: Int) -> Bool {
        checkedDraws.contains { drawCheck in
            drawCheck.lottoMatchedNumbers.contains(number) ||
            drawCheck.plusMatchedNumbers.contains(number)
        }
    }
    
    func isExtraNumberMatched(_ number: Int) -> Bool {
        checkedDraws.contains { drawCheck in
            drawCheck.extraMatchedNumbers.contains(number)
        }
    }
    
    func isNumberMatched(_ number: Int, in line: TicketLine) -> Bool {
        checkedDraws.contains { drawCheck in
            drawCheck.lineResults.contains { lineResult in
                lineResult.line.id == line.id &&
                (
                    lineResult.lottoMatchedNumbers.contains(number) ||
                    lineResult.plusMatchedNumbers.contains(number)
                )
            }
        }
    }
    
    func isExtraNumberMatched(_ number: Int, in line: TicketLine) -> Bool {
        checkedDraws.contains { drawCheck in
            drawCheck.lineResults.contains { lineResult in
                lineResult.line.id == line.id &&
                lineResult.extraMatchedNumbers.contains(number)
            }
        }
    }
}

struct TicketChecker {
    private let repository: LottoRepository
    
    init() {
        self.repository = LottoRepository.shared
    }
    
    init(repository: LottoRepository) {
        self.repository = repository
    }
    
    func check(ticket: LottoTicket) -> TicketCheckResult {
        let fallbackDraws = repository.draws(for: ticket.game)
        return check(ticket: ticket, drawResults: fallbackDraws)
    }
    
    func check(
        ticket: LottoTicket,
        drawResults: [DrawResult]
    ) -> TicketCheckResult {
        let matchingDrawResults = drawResults.filter { result in
            result.game == ticket.game
        }
        
        let checkedDraws = ticket.drawDates.compactMap { drawDate -> SingleDrawCheckResult? in
            guard let result = matchingDrawResults.first(where: { result in
                Calendar.current.isDate(result.drawDate, inSameDayAs: drawDate)
            }) else {
                return nil
            }
            
            return makeSingleDrawCheckResult(
                ticket: ticket,
                result: result
            )
        }
        
        let status = calculateStatus(
            ticket: ticket,
            checkedDrawsCount: checkedDraws.count
        )
        
        return TicketCheckResult(
            status: status,
            checkedDraws: checkedDraws,
            totalDrawsCount: ticket.drawDates.count
        )
    }
    
    private func makeSingleDrawCheckResult(
        ticket: LottoTicket,
        result: DrawResult
    ) -> SingleDrawCheckResult {
        let lottoNumbers = Set(result.numbers)
        let plusNumbersSet = Set(result.plusNumbers ?? [])
        let extraNumbersSet = Set(result.extraNumbers ?? [])
        
        let hasPlusResult = result.plusNumbers != nil
        let hasExtraResult = result.extraNumbers != nil
        
        let lineResults = ticket.lines.enumerated().map { index, line in
            let lottoMatchedNumbers = line.numbers.filter {
                lottoNumbers.contains($0)
            }
            
            let plusMatchedNumbers: [Int]
            
            if ticket.includesPlus {
                plusMatchedNumbers = line.numbers.filter {
                    plusNumbersSet.contains($0)
                }
            } else {
                plusMatchedNumbers = []
            }
            
            let extraMatchedNumbers = line.extraNumbers.filter {
                extraNumbersSet.contains($0)
            }
            
            return TicketLineCheckResult(
                line: line,
                lineIndex: index,
                lottoMatchedNumbers: lottoMatchedNumbers.sorted(),
                plusMatchedNumbers: plusMatchedNumbers.sorted(),
                extraMatchedNumbers: extraMatchedNumbers.sorted()
            )
        }
        
        return SingleDrawCheckResult(
            drawDate: result.drawDate,
            lineResults: lineResults,
            hasPlusResult: hasPlusResult,
            hasExtraResult: hasExtraResult
        )
    }
    
    private func calculateStatus(
        ticket: LottoTicket,
        checkedDrawsCount: Int
    ) -> TicketStatus {
        if checkedDrawsCount == ticket.drawDates.count {
            return .checked
        }
        
        if checkedDrawsCount > 0 {
            return .partiallyChecked
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        let hasFutureDraw = ticket.drawDates.contains { drawDate in
            Calendar.current.startOfDay(for: drawDate) >= today
        }
        
        if hasFutureDraw {
            return .active
        } else {
            return .waitingForResults
        }
    }
}
