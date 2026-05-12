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

struct SingleDrawCheckResult: Identifiable {
    let id: Date
    let drawDate: Date
    let lottoMatchedNumbers: [Int]
    let plusMatchedNumbers: [Int]
    let extraMatchedNumbers: [Int]
    let hasPlusResult: Bool
    let hasExtraResult: Bool
    
    init(
        drawDate: Date,
        lottoMatchedNumbers: [Int],
        plusMatchedNumbers: [Int],
        extraMatchedNumbers: [Int],
        hasPlusResult: Bool,
        hasExtraResult: Bool
    ) {
        self.id = drawDate
        self.drawDate = drawDate
        self.lottoMatchedNumbers = lottoMatchedNumbers
        self.plusMatchedNumbers = plusMatchedNumbers
        self.extraMatchedNumbers = extraMatchedNumbers
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
        let checkedDraws = ticket.drawDates.compactMap { drawDate -> SingleDrawCheckResult? in
            guard let result = repository.result(
                for: ticket.gameName,
                drawDate: drawDate
            ) else {
                return nil
            }
            
            let lottoNumbers = Set(result.numbers)
            let lottoMatchedNumbers = ticket.numbers.filter {
                lottoNumbers.contains($0)
            }
            
            let hasPlusResult = result.plusNumbers != nil
            
            let plusMatchedNumbers: [Int]
            
            if ticket.includesPlus, let plusNumbers = result.plusNumbers {
                let plusNumbersSet = Set(plusNumbers)
                plusMatchedNumbers = ticket.numbers.filter {
                    plusNumbersSet.contains($0)
                }
            } else {
                plusMatchedNumbers = []
            }
            
            let hasExtraResult = result.extraNumbers != nil
            
            let extraMatchedNumbers: [Int]
            
            if let resultExtraNumbers = result.extraNumbers {
                let extraNumbersSet = Set(resultExtraNumbers)
                extraMatchedNumbers = ticket.extraNumbers.filter {
                    extraNumbersSet.contains($0)
                }
            } else {
                extraMatchedNumbers = []
            }
            
            return SingleDrawCheckResult(
                drawDate: result.drawDate,
                lottoMatchedNumbers: lottoMatchedNumbers,
                plusMatchedNumbers: plusMatchedNumbers,
                extraMatchedNumbers: extraMatchedNumbers,
                hasPlusResult: hasPlusResult,
                hasExtraResult: hasExtraResult
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
