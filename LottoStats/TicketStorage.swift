import Foundation

struct TicketStorage {
    private static let ticketsKey = "saved_lotto_tickets"
    
    static func save(_ tickets: [LottoTicket]) {
        do {
            let data = try JSONEncoder().encode(tickets)
            UserDefaults.standard.set(data, forKey: ticketsKey)
        } catch {
            print("Błąd zapisu kuponów: \(error.localizedDescription)")
        }
    }
    
    static func load() -> [LottoTicket] {
        guard let data = UserDefaults.standard.data(forKey: ticketsKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([LottoTicket].self, from: data)
        } catch {
            print("Błąd odczytu kuponów: \(error.localizedDescription)")
            return []
        }
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: ticketsKey)
    }
}
