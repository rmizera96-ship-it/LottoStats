import Foundation

struct UserBestResult: Identifiable {
    let id = UUID()
    let gameName: String
    let drawDate: Date
    let lineIndex: Int
    let mainHits: Int
    let mainTotal: Int
    let plusHits: Int?
    let plusTotal: Int?
    let extraHits: Int?
    let extraTotal: Int?
    
    var totalHits: Int {
        mainHits + (plusHits ?? 0) + (extraHits ?? 0)
    }
    
    var scoreText: String {
        var parts = [
            "Główne: \(mainHits)/\(mainTotal)"
        ]
        
        if let extraHits, let extraTotal {
            parts.append("Euroliczby: \(extraHits)/\(extraTotal)")
        }
        
        if let plusHits, let plusTotal {
            parts.append("Plus: \(plusHits)/\(plusTotal)")
        }
        
        return parts.joined(separator: " • ")
    }
    
    var titleText: String {
        "\(gameName), zestaw \(lineIndex + 1)"
    }
}

struct BestResultCalculator {
    private let ticketChecker: TicketChecker
    
    init(ticketChecker: TicketChecker = TicketChecker()) {
        self.ticketChecker = ticketChecker
    }
    
    func calculate(from tickets: [LottoTicket]) -> UserBestResult? {
        let allResults = tickets.flatMap { ticket in
            resultsForTicket(ticket)
        }
        
        return allResults.max { first, second in
            if first.totalHits == second.totalHits {
                return first.mainHits < second.mainHits
            }
            
            return first.totalHits < second.totalHits
        }
    }
    
    private func resultsForTicket(_ ticket: LottoTicket) -> [UserBestResult] {
        let checkResult = ticketChecker.check(ticket: ticket)
        
        return checkResult.checkedDraws.flatMap { drawCheck in
            drawCheck.lineResults.map { lineResult in
                UserBestResult(
                    gameName: ticket.gameName,
                    drawDate: drawCheck.drawDate,
                    lineIndex: lineResult.lineIndex,
                    mainHits: lineResult.lottoMatchedNumbers.count,
                    mainTotal: lineResult.line.numbers.count,
                    plusHits: ticket.includesPlus && drawCheck.hasPlusResult ? lineResult.plusMatchedNumbers.count : nil,
                    plusTotal: ticket.includesPlus && drawCheck.hasPlusResult ? lineResult.line.numbers.count : nil,
                    extraHits: !lineResult.line.extraNumbers.isEmpty && drawCheck.hasExtraResult ? lineResult.extraMatchedNumbers.count : nil,
                    extraTotal: !lineResult.line.extraNumbers.isEmpty && drawCheck.hasExtraResult ? lineResult.line.extraNumbers.count : nil
                )
            }
        }
    }
}
