import Foundation

enum TicketStorage {
    private static let legacyTicketsKey = "saved_lotto_tickets"
    private static let guestTicketsKey = "saved_lotto_tickets_guest"
    private static let userTicketsKeyPrefix = "saved_lotto_tickets_user_"
    private static let legacyMigrationKey = "saved_lotto_tickets_legacy_migrated"

    static func save(_ tickets: [LottoTicket], userID: String?) {
        do {
            let data = try JSONEncoder().encode(tickets)
            UserDefaults.standard.set(data, forKey: storageKey(userID: userID))
        } catch {
            AppLogger.debug("Błąd zapisu kuponów:", error.localizedDescription)
        }
    }

    static func load(userID: String?) -> [LottoTicket] {
        migrateLegacyTicketsIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: storageKey(userID: userID)) else {
            return []
        }

        do {
            return try JSONDecoder().decode([LottoTicket].self, from: data)
        } catch {
            AppLogger.debug("Błąd odczytu kuponów:", error.localizedDescription)
            return []
        }
    }

    static func clear(userID: String?) {
        UserDefaults.standard.removeObject(forKey: storageKey(userID: userID))
    }

    private static func storageKey(userID: String?) -> String {
        guard let userID, !userID.isEmpty else {
            return guestTicketsKey
        }

        return userTicketsKeyPrefix + userID
    }

    private static func migrateLegacyTicketsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: legacyMigrationKey) else {
            return
        }

        defer {
            UserDefaults.standard.set(true, forKey: legacyMigrationKey)
        }

        guard UserDefaults.standard.data(forKey: guestTicketsKey) == nil,
              let legacyData = UserDefaults.standard.data(forKey: legacyTicketsKey) else {
            return
        }

        UserDefaults.standard.set(legacyData, forKey: guestTicketsKey)
        UserDefaults.standard.removeObject(forKey: legacyTicketsKey)
    }
}
