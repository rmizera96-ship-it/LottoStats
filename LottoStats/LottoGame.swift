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
    
    var supportsPlus: Bool {
        self == .lotto
    }
    
    var isImplemented: Bool {
        self == .lotto
    }
    
    static func fromDisplayName(_ name: String) -> LottoGame? {
        LottoGame.allCases.first { game in
            game.displayName == name
        }
    }
}
