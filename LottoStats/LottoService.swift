import Foundation

enum LottoServiceError: Error, LocalizedError {
    case unsupportedGame
    case noData
    case invalidURL
    case invalidResponse
    case unauthorized
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedGame:
            return "Ta gra nie jest jeszcze obsługiwana."
        case .noData:
            return "Brak danych dla wybranej gry."
        case .invalidURL:
            return "Niepoprawny adres API."
        case .invalidResponse:
            return "Niepoprawna odpowiedź serwera."
        case .unauthorized:
            return "Brak autoryzacji. Sprawdź klucz API."
        case .decodingFailed:
            return "Nie udało się odczytać danych z API."
        }
    }
}

protocol LottoService {
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult]
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult?
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date]
}

// MARK: - Mock service

struct MockLottoService: LottoService {
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult] {
        try await simulateNetworkDelay()
        
        guard game.isImplemented else {
            return []
        }
        
        return DrawResult.samples
            .filter { $0.game == game }
            .sorted { $0.drawDate > $1.drawDate }
    }
    
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult? {
        let draws = try await fetchDraws(for: game)
        return draws.first
    }
    
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date] {
        try await simulateNetworkDelay()
        
        guard game.isImplemented else {
            return []
        }
        
        return DrawResult.upcomingDrawDates(for: game, count: count)
    }
    
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}

// MARK: - Real API service

struct OpenLottoService: LottoService {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    
    init(
        baseURL: URL = LottoAPIConfiguration.baseURL,
        apiKey: String = LottoAPIConfiguration.apiKey,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }
    
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult] {
        guard game.isImplemented else {
            throw LottoServiceError.unsupportedGame
        }
        
        let mainDraws = try await fetchLastResults(for: game.apiGameType)
            .compactMap { apiDraw in
                mapAPIDrawToDrawResult(apiDraw, fallbackGame: game)
            }
        
        if game == .lotto {
            let plusDraws = try await fetchLastResults(for: "LottoPlus")
                .compactMap { apiDraw in
                    mapAPIDrawToDrawResult(apiDraw, fallbackGame: .lotto)
                }
            
            return mergeLottoWithPlus(
                lottoDraws: mainDraws,
                plusDraws: plusDraws
            )
            .sorted { $0.drawDate > $1.drawDate }
        }
        
        return mainDraws.sorted { $0.drawDate > $1.drawDate }
    }
    
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult? {
        let draws = try await fetchDraws(for: game)
        return draws.first
    }
    
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date] {
        guard game.isImplemented else {
            throw LottoServiceError.unsupportedGame
        }
        
        let nextDraw = try await fetchNextDrawDate(for: game)
        
        guard let nextDraw else {
            return []
        }
        
        let fallbackDates = DrawResult.upcomingDrawDates(for: game, count: count)
        let remainingDates = fallbackDates.filter { date in
            !Calendar.current.isDate(date, inSameDayAs: nextDraw)
        }
        
        return Array(([nextDraw] + remainingDates).prefix(count))
    }
    
    private func fetchLastResults(for apiGameType: String) async throws -> [APIDrawResponse] {
        let url = try makeURL(
            path: "lotteries/draw-results/last-results-per-game",
            queryItems: [
                URLQueryItem(name: "gameType", value: apiGameType)
            ]
        )
        
        return try await request(url)
    }
    
    private func fetchNextDrawDate(for game: LottoGame) async throws -> Date? {
        let url = try makeURL(
            path: "lotteries/info/next-draw",
            queryItems: [
                URLQueryItem(name: "gameType", value: game.apiGameType)
            ]
        )
        
        let response: APINextDrawResponse = try await request(url)
        return response.nextDrawDate
    }
    
    private func makeURL(
        path: String,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw LottoServiceError.invalidURL
        }
        
        return url
    }
    
    private func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "secret")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LottoServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw LottoServiceError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw LottoServiceError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                if let date = ISO8601DateFormatter.lotto.date(from: dateString) {
                    return date
                }
                
                if let date = ISO8601DateFormatter.lottoWithFractionalSeconds.date(from: dateString) {
                    return date
                }
                
                if let date = DateFormatter.lottoDateTime.date(from: dateString) {
                    return date
                }
                
                if let date = DateFormatter.lottoDateOnly.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Niepoprawny format daty: \(dateString)"
                )
            }
            
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Błąd dekodowania API: \(error)")
            throw LottoServiceError.decodingFailed
        }
    }
    
    private func mapAPIDrawToDrawResult(
        _ apiDraw: APIDrawResponse,
        fallbackGame: LottoGame
    ) -> DrawResult? {
        let firstResult = apiDraw.results?.first
        
        let apiGameName = firstResult?.gameType ?? apiDraw.gameType
        let game = apiGameName.flatMap { LottoGame.fromAPIName($0) } ?? fallbackGame
        
        let drawDate = firstResult?.drawDate ?? apiDraw.drawDate
        let numbers = firstResult?.resultsJson ?? []
        let specialResults = firstResult?.specialResults ?? []
        
        guard let drawDate, !numbers.isEmpty else {
            return nil
        }
        
        switch game {
        case .eurojackpot:
            return DrawResult(
                game: game,
                drawDate: drawDate,
                numbers: numbers,
                extraNumbers: specialResults
            )
            
        case .lotto:
            return DrawResult(
                game: game,
                drawDate: drawDate,
                numbers: numbers,
                plusNumbers: specialResults.isEmpty ? nil : specialResults
            )
            
        case .miniLotto:
            return DrawResult(
                game: game,
                drawDate: drawDate,
                numbers: numbers
            )
        }
    }
    
    private func mergeLottoWithPlus(
        lottoDraws: [DrawResult],
        plusDraws: [DrawResult]
    ) -> [DrawResult] {
        lottoDraws.map { lottoDraw in
            let matchingPlusDraw = plusDraws.first { plusDraw in
                Calendar.current.isDate(
                    lottoDraw.drawDate,
                    inSameDayAs: plusDraw.drawDate
                )
            }
            
            return DrawResult(
                game: lottoDraw.game,
                drawDate: lottoDraw.drawDate,
                numbers: lottoDraw.numbers,
                plusNumbers: matchingPlusDraw?.numbers ?? lottoDraw.plusNumbers,
                extraNumbers: lottoDraw.extraNumbers
            )
        }
    }
}

// MARK: - API DTO

private struct APIDrawResponse: Decodable {
    let drawSystemId: Int?
    let drawDate: Date?
    let gameType: String?
    let multiplierValue: Int?
    let results: [APIDrawResult]?
    let showSpecialResults: Bool?
    let isNewEuroJackpotDraw: Bool?
}

private struct APIDrawResult: Decodable {
    let drawDate: Date?
    let drawSystemId: Int?
    let gameType: String?
    let resultsJson: [Int]?
    let specialResults: [Int]?
}

private struct APINextDrawResponse: Decodable {
    let gameType: String?
    let closestPrizeValue: Double?
    let nextDrawDate: Date?
    let playSitePath: String?
}

// MARK: - Date helpers

private extension ISO8601DateFormatter {
    static let lotto: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime
        ]
        return formatter
    }()
    
    static let lottoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()
}

private extension DateFormatter {
    static let lottoDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
    
    static let lottoDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
