import Foundation
import FirebaseFirestore

@MainActor
final class CloudTicketService {
    static let shared = CloudTicketService()

    private var database: Firestore {
        Firestore.firestore()
    }

    private init() {}

    func ensureUserDocument(userID: String, email: String?) {
        var data: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let email, !email.isEmpty {
            data["email"] = email
        }

        database
            .collection("users")
            .document(userID)
            .setData(data, merge: true)
    }

    func fetchTickets(userID: String) async throws -> [LottoTicket] {
        let snapshot = try await ticketCollection(userID: userID).getDocuments()

        return snapshot.documents
            .compactMap { document in
                decodeTicket(from: document.data(), fallbackID: document.documentID)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func saveTicket(_ ticket: LottoTicket, userID: String) {
        ticketCollection(userID: userID)
            .document(ticket.id.uuidString)
            .setData(ticketDictionary(ticket), merge: true)
    }

    func uploadTickets(_ tickets: [LottoTicket], userID: String) {
        guard !tickets.isEmpty else {
            return
        }

        for chunkStart in stride(from: 0, to: tickets.count, by: 400) {
            let chunkEnd = min(chunkStart + 400, tickets.count)
            let batch = database.batch()

            for ticket in tickets[chunkStart..<chunkEnd] {
                let reference = ticketCollection(userID: userID)
                    .document(ticket.id.uuidString)
                batch.setData(ticketDictionary(ticket), forDocument: reference, merge: true)
            }

            batch.commit()
        }
    }

    func deleteTicket(id: UUID, userID: String) {
        ticketCollection(userID: userID)
            .document(id.uuidString)
            .delete()
    }

    func deleteTickets(ids: [UUID], userID: String) {
        guard !ids.isEmpty else {
            return
        }

        for chunkStart in stride(from: 0, to: ids.count, by: 400) {
            let chunkEnd = min(chunkStart + 400, ids.count)
            let batch = database.batch()

            for id in ids[chunkStart..<chunkEnd] {
                let reference = ticketCollection(userID: userID)
                    .document(id.uuidString)
                batch.deleteDocument(reference)
            }

            batch.commit()
        }
    }

    private func ticketCollection(userID: String) -> CollectionReference {
        database
            .collection("users")
            .document(userID)
            .collection("tickets")
    }

    private func ticketDictionary(_ ticket: LottoTicket) -> [String: Any] {
        [
            "id": ticket.id.uuidString,
            "gameName": ticket.gameName,
            "lines": ticket.lines.map { line in
                [
                    "id": line.id.uuidString,
                    "numbers": line.numbers,
                    "extraNumbers": line.extraNumbers
                ]
            },
            "drawDate": Timestamp(date: ticket.drawDate),
            "drawDates": ticket.drawDates.map { Timestamp(date: $0) },
            "includesPlus": ticket.includesPlus,
            "createdAt": Timestamp(date: ticket.createdAt),
            "updatedAt": FieldValue.serverTimestamp(),
            "schemaVersion": 1
        ]
    }

    private func decodeTicket(
        from data: [String: Any],
        fallbackID: String
    ) -> LottoTicket? {
        guard let id = UUID(uuidString: data["id"] as? String ?? fallbackID),
              let gameName = data["gameName"] as? String,
              let drawDate = date(from: data["drawDate"]),
              let createdAt = date(from: data["createdAt"]),
              let rawLines = data["lines"] as? [[String: Any]] else {
            AppLogger.debug("Pominięto nieprawidłowy dokument kuponu z Firestore:", fallbackID)
            return nil
        }

        let lines = rawLines.compactMap { rawLine -> TicketLine? in
            guard let lineID = UUID(uuidString: rawLine["id"] as? String ?? ""),
                  let numbers = integerArray(from: rawLine["numbers"]) else {
                return nil
            }

            let extraNumbers = integerArray(from: rawLine["extraNumbers"]) ?? []

            return TicketLine(
                id: lineID,
                numbers: numbers,
                extraNumbers: extraNumbers
            )
        }

        guard !lines.isEmpty else {
            return nil
        }

        let drawDates = (data["drawDates"] as? [Any])?
            .compactMap(date(from:)) ?? [drawDate]

        return LottoTicket(
            id: id,
            gameName: gameName,
            lines: lines,
            drawDate: drawDate,
            drawDates: drawDates.isEmpty ? [drawDate] : drawDates,
            includesPlus: data["includesPlus"] as? Bool ?? false,
            createdAt: createdAt
        )
    }

    private func date(from value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }

        return value as? Date
    }

    private func integerArray(from value: Any?) -> [Int]? {
        guard let values = value as? [Any] else {
            return nil
        }

        return values.compactMap { item in
            if let number = item as? NSNumber {
                return number.intValue
            }

            return item as? Int
        }
    }
}
