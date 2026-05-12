import Foundation

struct LottoTicket: Identifiable {
    let id: UUID
    let gameName: String
    let numbers: [Int]
    let drawDate: Date
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        gameName: String = "Lotto",
        numbers: [Int],
        drawDate: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.gameName = gameName
        self.numbers = numbers
        self.drawDate = drawDate
        self.createdAt = createdAt
    }
}

extension LottoTicket {
    static let samples: [LottoTicket] = []
}
