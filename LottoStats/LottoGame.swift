import Foundation

enum LottoGame: String, CaseIterable, Identifiable, Codable {
    case lotto = "Lotto"
    case miniLotto = "Mini Lotto"
    case eurojackpot = "Eurojackpot"
    
    var id: String {
        rawValue
    }
    
    var displayName: String {
        rawValue
    }
    
    var apiGameType: String {
        switch self {
        case .lotto:
            return "Lotto"
        case .miniLotto:
            return "MiniLotto"
        case .eurojackpot:
            return "EuroJackpot"
        }
    }
    
    var supportsPlus: Bool {
        self == .lotto
    }
    
    var isImplemented: Bool {
        self == .lotto || self == .miniLotto || self == .eurojackpot
    }
    
    static func fromDisplayName(_ name: String) -> LottoGame? {
        LottoGame.allCases.first { game in
            game.displayName == name
        }
    }
    
    static func fromAPIName(_ name: String) -> LottoGame? {
        LottoGame.allCases.first { game in
            game.apiGameType.lowercased() == name.lowercased()
        }
    }
}
