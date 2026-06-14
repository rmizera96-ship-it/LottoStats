import Foundation

struct TicketPrizeWin: Identifiable, Equatable {
    enum Source: String {
        case main = "Gra główna"
        case plus = "Lotto Plus"
    }

    let drawDate: Date
    let lineIndex: Int
    let source: Source
    let rank: String
    let mainMatches: Int
    let extraMatches: Int
    let amount: Double

    var id: String {
        "\(drawDate.timeIntervalSince1970)-\(lineIndex)-\(source.rawValue)-\(rank)"
    }

    var rankDisplayName: String {
        switch Int(rank) {
        case 1: return "I stopień"
        case 2: return "II stopień"
        case 3: return "III stopień"
        case 4: return "IV stopień"
        case 5: return "V stopień"
        case 6: return "VI stopień"
        case 7: return "VII stopień"
        case 8: return "VIII stopień"
        case 9: return "IX stopień"
        case 10: return "X stopień"
        case 11: return "XI stopień"
        case 12: return "XII stopień"
        default: return "Stopień \(rank)"
        }
    }

    var matchDescription: String {
        if extraMatches > 0 {
            return "\(mainMatches) + \(extraMatches)"
        }

        return "\(mainMatches) liczby"
    }
}

struct TicketWinningsSummary: Equatable {
    let wins: [TicketPrizeWin]
    let checkedDrawsCount: Int
    let loadedDrawsCount: Int

    var totalAmount: Double {
        wins.reduce(0) { $0 + $1.amount }
    }

    var hasAnyWin: Bool {
        totalAmount > 0
    }

    var isComplete: Bool {
        checkedDrawsCount > 0 && checkedDrawsCount == loadedDrawsCount
    }

    func wins(for drawDate: Date) -> [TicketPrizeWin] {
        wins.filter {
            Calendar.current.isDate($0.drawDate, inSameDayAs: drawDate)
        }
    }

    func wins(for drawDate: Date, lineIndex: Int) -> [TicketPrizeWin] {
        wins(for: drawDate).filter { $0.lineIndex == lineIndex }
    }
}

struct TicketPrizeCalculator {
    static func drawKey(
        game: LottoGame,
        drawSystemId: Int?,
        drawDate: Date
    ) -> String {
        let day = Calendar.current.startOfDay(for: drawDate).timeIntervalSince1970
        return "\(game.rawValue)|\(drawSystemId ?? 0)|\(day)"
    }

    func calculate(
        ticket: LottoTicket,
        checkResult: TicketCheckResult,
        prizeInfoByDrawKey: [String: [LottoDrawPrizeInfo]],
        loadedDrawKeys: Set<String>
    ) -> TicketWinningsSummary {
        var wins: [TicketPrizeWin] = []
        var loadedDrawsCount = 0

        for drawCheck in checkResult.checkedDraws {
            let key = Self.drawKey(
                game: ticket.game,
                drawSystemId: drawCheck.drawSystemId,
                drawDate: drawCheck.drawDate
            )

            guard loadedDrawKeys.contains(key) else {
                continue
            }

            loadedDrawsCount += 1
            let prizeInfos = prizeInfoByDrawKey[key] ?? []

            for lineResult in drawCheck.lineResults {
                if let win = mainWin(
                    ticket: ticket,
                    drawCheck: drawCheck,
                    lineResult: lineResult,
                    prizeInfos: prizeInfos
                ) {
                    wins.append(win)
                }

                if let plusWin = plusWin(
                    ticket: ticket,
                    drawCheck: drawCheck,
                    lineResult: lineResult,
                    prizeInfos: prizeInfos
                ) {
                    wins.append(plusWin)
                }
            }
        }

        return TicketWinningsSummary(
            wins: wins.sorted {
                if $0.drawDate == $1.drawDate {
                    return $0.lineIndex < $1.lineIndex
                }
                return $0.drawDate > $1.drawDate
            },
            checkedDrawsCount: checkResult.checkedDrawsCount,
            loadedDrawsCount: loadedDrawsCount
        )
    }

    private func mainWin(
        ticket: LottoTicket,
        drawCheck: SingleDrawCheckResult,
        lineResult: TicketLineCheckResult,
        prizeInfos: [LottoDrawPrizeInfo]
    ) -> TicketPrizeWin? {
        let mainMatches = lineResult.lottoMatchedNumbers.count
        let extraMatches = lineResult.extraMatchedNumbers.count

        guard let rank = rank(
            for: ticket.game,
            mainMatches: mainMatches,
            extraMatches: extraMatches
        ),
        let prizeInfo = mainPrizeInfo(for: ticket.game, in: prizeInfos),
        let prizeRank = prizeInfo.ranks.first(where: { $0.rank == rank }),
        prizeRank.prizeValue > 0 else {
            return nil
        }

        return TicketPrizeWin(
            drawDate: drawCheck.drawDate,
            lineIndex: lineResult.lineIndex,
            source: .main,
            rank: rank,
            mainMatches: mainMatches,
            extraMatches: extraMatches,
            amount: prizeRank.prizeValue
        )
    }

    private func plusWin(
        ticket: LottoTicket,
        drawCheck: SingleDrawCheckResult,
        lineResult: TicketLineCheckResult,
        prizeInfos: [LottoDrawPrizeInfo]
    ) -> TicketPrizeWin? {
        guard ticket.game == .lotto,
              ticket.includesPlus,
              drawCheck.hasPlusResult else {
            return nil
        }

        let matches = lineResult.plusMatchedNumbers.count

        guard let rank = rank(
            for: .lotto,
            mainMatches: matches,
            extraMatches: 0
        ),
        let prizeInfo = plusPrizeInfo(in: prizeInfos),
        let prizeRank = prizeInfo.ranks.first(where: { $0.rank == rank }),
        prizeRank.prizeValue > 0 else {
            return nil
        }

        return TicketPrizeWin(
            drawDate: drawCheck.drawDate,
            lineIndex: lineResult.lineIndex,
            source: .plus,
            rank: rank,
            mainMatches: matches,
            extraMatches: 0,
            amount: prizeRank.prizeValue
        )
    }

    // Rank numbers follow the order used by the draw-prizes API.
    private func rank(
        for game: LottoGame,
        mainMatches: Int,
        extraMatches: Int
    ) -> String? {
        switch game {
        case .lotto:
            switch mainMatches {
            case 6: return "1"
            case 5: return "2"
            case 4: return "3"
            case 3: return "4"
            default: return nil
            }

        case .miniLotto:
            switch mainMatches {
            case 5: return "1"
            case 4: return "2"
            case 3: return "3"
            default: return nil
            }

        case .eurojackpot:
            switch (mainMatches, extraMatches) {
            case (5, 2): return "1"
            case (5, 1): return "2"
            case (5, 0): return "3"
            case (4, 2): return "4"
            case (4, 1): return "5"
            case (3, 2): return "6"
            case (4, 0): return "7"
            case (2, 2): return "8"
            case (3, 1): return "9"
            case (3, 0): return "10"
            case (1, 2): return "11"
            case (2, 1): return "12"
            default: return nil
            }
        }
    }

    // Lotto and Lotto Plus can arrive as separate prize tables for one draw.
    private func mainPrizeInfo(
        for game: LottoGame,
        in prizeInfos: [LottoDrawPrizeInfo]
    ) -> LottoDrawPrizeInfo? {
        switch game {
        case .lotto:
            return prizeInfos.first {
                let name = normalized($0.gameType)
                return name.contains("lotto") && !name.contains("plus")
            } ?? prizeInfos.first { !normalized($0.gameType).contains("plus") }

        case .miniLotto:
            return prizeInfos.first {
                normalized($0.gameType).contains("minilotto")
            } ?? prizeInfos.first

        case .eurojackpot:
            return prizeInfos.first {
                normalized($0.gameType).contains("eurojackpot")
            } ?? prizeInfos.first
        }
    }

    private func plusPrizeInfo(
        in prizeInfos: [LottoDrawPrizeInfo]
    ) -> LottoDrawPrizeInfo? {
        prizeInfos.first {
            normalized($0.gameType).contains("plus")
        }
    }

    private func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
