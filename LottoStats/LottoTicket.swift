import Foundation

struct LottoTicket: Identifiable, Codable, Equatable {
    let id: UUID
    let gameName: String
    let numbers: [Int]
    let drawDate: Date
    let includesPlus: Bool
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        gameName: String = "Lotto",
        numbers: [Int],
        drawDate: Date,
        includesPlus: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.gameName = gameName
        self.numbers = numbers
        self.drawDate = drawDate
        self.includesPlus = includesPlus
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case gameName
        case numbers
        case drawDate
        case includesPlus
        case createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        gameName = try container.decode(String.self, forKey: .gameName)
        numbers = try container.decode([Int].self, forKey: .numbers)
        drawDate = try container.decode(Date.self, forKey: .drawDate)
        includesPlus = try container.decodeIfPresent(Bool.self, forKey: .includesPlus) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

extension LottoTicket {
    static let samples: [LottoTicket] = []
}
