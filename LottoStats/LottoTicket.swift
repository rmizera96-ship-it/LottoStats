import Foundation

struct LottoTicket: Identifiable, Codable, Equatable {
    let id: UUID
    let gameName: String
    let lines: [TicketLine]
    let drawDate: Date
    let drawDates: [Date]
    let includesPlus: Bool
    let createdAt: Date
    
    var game: LottoGame {
        LottoGame.fromDisplayName(gameName) ?? .lotto
    }

    var numbers: [Int] {
        lines.first?.numbers ?? []
    }
    
    var extraNumbers: [Int] {
        lines.first?.extraNumbers ?? []
    }
    
    init(
        id: UUID = UUID(),
        gameName: String = LottoGame.lotto.displayName,
        lines: [TicketLine],
        drawDate: Date,
        drawDates: [Date]? = nil,
        includesPlus: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.gameName = gameName
        self.lines = lines
        self.drawDate = drawDate
        self.drawDates = drawDates ?? [drawDate]
        self.includesPlus = includesPlus
        self.createdAt = createdAt
    }
    
    init(
        id: UUID = UUID(),
        gameName: String = LottoGame.lotto.displayName,
        numbers: [Int],
        extraNumbers: [Int] = [],
        drawDate: Date,
        drawDates: [Date]? = nil,
        includesPlus: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.gameName = gameName
        self.lines = [
            TicketLine(
                numbers: numbers,
                extraNumbers: extraNumbers
            )
        ]
        self.drawDate = drawDate
        self.drawDates = drawDates ?? [drawDate]
        self.includesPlus = includesPlus
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case gameName
        case lines
        case numbers
        case extraNumbers
        case drawDate
        case drawDates
        case includesPlus
        case createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        gameName = try container.decode(String.self, forKey: .gameName)
        drawDate = try container.decode(Date.self, forKey: .drawDate)
        drawDates = try container.decodeIfPresent([Date].self, forKey: .drawDates) ?? [drawDate]
        includesPlus = try container.decodeIfPresent(Bool.self, forKey: .includesPlus) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        if let decodedLines = try container.decodeIfPresent([TicketLine].self, forKey: .lines) {
            lines = decodedLines
        } else {
            let legacyNumbers = try container.decodeIfPresent([Int].self, forKey: .numbers) ?? []
            let legacyExtraNumbers = try container.decodeIfPresent([Int].self, forKey: .extraNumbers) ?? []
            
            if legacyNumbers.isEmpty {
                lines = []
            } else {
                lines = [
                    TicketLine(
                        numbers: legacyNumbers,
                        extraNumbers: legacyExtraNumbers
                    )
                ]
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(gameName, forKey: .gameName)
        try container.encode(lines, forKey: .lines)
        try container.encode(drawDate, forKey: .drawDate)
        try container.encode(drawDates, forKey: .drawDates)
        try container.encode(includesPlus, forKey: .includesPlus)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension LottoTicket {
    static let samples: [LottoTicket] = []
}
