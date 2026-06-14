import Foundation

struct TicketLine: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let numbers: [Int]
    let extraNumbers: [Int]
    
    init(
        id: UUID = UUID(),
        numbers: [Int],
        extraNumbers: [Int] = []
    ) {
        self.id = id
        self.numbers = numbers
        self.extraNumbers = extraNumbers
    }
}
