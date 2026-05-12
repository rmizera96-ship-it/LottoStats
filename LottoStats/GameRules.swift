import Foundation

struct GameRules {
    let game: LottoGame
    let mainNumbersCount: Int
    let mainNumberRange: ClosedRange<Int>
    let extraNumbersCount: Int
    let extraNumberRange: ClosedRange<Int>?
    let supportsPlus: Bool
    let supportsTicketsInCurrentVersion: Bool
    
    var description: String {
        if let extraNumberRange {
            return "\(mainNumbersCount) z \(mainNumberRange.upperBound) + \(extraNumbersCount) z \(extraNumberRange.upperBound)"
        } else {
            return "\(mainNumbersCount) z \(mainNumberRange.upperBound)"
        }
    }
    
    var inputPlaceholderText: String {
        if let extraNumberRange {
            return "Wybierz \(mainNumbersCount) liczb z zakresu \(mainNumberRange.lowerBound)-\(mainNumberRange.upperBound) oraz \(extraNumbersCount) liczb z zakresu \(extraNumberRange.lowerBound)-\(extraNumberRange.upperBound)."
        } else {
            return "Wybierz \(mainNumbersCount) liczb z zakresu \(mainNumberRange.lowerBound)-\(mainNumberRange.upperBound)."
        }
    }
    
    static func rules(for game: LottoGame) -> GameRules {
        switch game {
        case .lotto:
            return GameRules(
                game: .lotto,
                mainNumbersCount: 6,
                mainNumberRange: 1...49,
                extraNumbersCount: 0,
                extraNumberRange: nil,
                supportsPlus: true,
                supportsTicketsInCurrentVersion: true
            )
            
        case .miniLotto:
            return GameRules(
                game: .miniLotto,
                mainNumbersCount: 5,
                mainNumberRange: 1...42,
                extraNumbersCount: 0,
                extraNumberRange: nil,
                supportsPlus: false,
                supportsTicketsInCurrentVersion: true
            )
            
        case .eurojackpot:
            return GameRules(
                game: .eurojackpot,
                mainNumbersCount: 5,
                mainNumberRange: 1...50,
                extraNumbersCount: 2,
                extraNumberRange: 1...12,
                supportsPlus: false,
                supportsTicketsInCurrentVersion: false
            )
        }
    }
}
