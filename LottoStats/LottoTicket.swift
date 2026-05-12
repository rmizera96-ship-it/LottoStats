import Foundation

struct LottoTicket: Identifiable {
    let id: UUID
    let numbers: [Int]
    let createdAt: Date
    
    init(id: UUID = UUID(), numbers: [Int], createdAt: Date = Date()) {
        self.id = id
        self.numbers = numbers
        self.createdAt = createdAt
    }
}

extension LottoTicket {
    static let samples: [LottoTicket] = []
}
