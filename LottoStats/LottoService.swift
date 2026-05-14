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

struct LottoGameAPIInfo {
    let game: LottoGame
    let nextDrawDate: Date?
    let closestPrizeValue: Double?
    let draws: String?
    let couponPrice: String?
    let closestPrizePoolType: String?
}

struct LottoJackpotAPIInfo {
    let game: LottoGame
    let jackpotValue: Double?
    let jackpotPlusValue: Double?
    let closestDraw: Date?
}

protocol LottoService {
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult]
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult?
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date]
    func fetchGameInfo(for game: LottoGame) async throws -> LottoGameAPIInfo?
    func fetchJackpotInfo(for game: LottoGame) async throws -> LottoJackpotAPIInfo?
}

extension LottoService {
    func fetchGameInfo(for game: LottoGame) async throws -> LottoGameAPIInfo? {
        nil
    }
    
    func fetchJackpotInfo(for game: LottoGame) async throws -> LottoJackpotAPIInfo? {
        nil
    }
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
            .map { sortedDraw($0) }
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
    
    func fetchGameInfo(for game: LottoGame) async throws -> LottoGameAPIInfo? {
        try await simulateNetworkDelay()
        
        return LottoGameAPIInfo(
            game: game,
            nextDrawDate: DrawResult.upcomingDrawDates(for: game, count: 1).first,
            closestPrizeValue: mockPrizeValue(for: game),
            draws: mockDrawsText(for: game),
            couponPrice: mockCouponPrice(for: game),
            closestPrizePoolType: "Guaranteed"
        )
    }
    
    func fetchJackpotInfo(for game: LottoGame) async throws -> LottoJackpotAPIInfo? {
        try await simulateNetworkDelay()
        
        guard game != .miniLotto else {
            return nil
        }
        
        return LottoJackpotAPIInfo(
            game: game,
            jackpotValue: mockPrizeValue(for: game),
            jackpotPlusValue: game == .lotto ? 1_000_000 : nil,
            closestDraw: DrawResult.upcomingDrawDates(for: game, count: 1).first
        )
    }
    
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func sortedDraw(_ draw: DrawResult) -> DrawResult {
        DrawResult(
            game: draw.game,
            drawDate: draw.drawDate,
            numbers: draw.numbers.sorted(),
            plusNumbers: draw.plusNumbers?.sorted(),
            extraNumbers: draw.extraNumbers?.sorted()
        )
    }
    
    private func mockPrizeValue(for game: LottoGame) -> Double? {
        switch game {
        case .lotto:
            return 2_000_000
        case .miniLotto:
            return nil
        case .eurojackpot:
            return 45_000_000
        }
    }
    
    private func mockDrawsText(for game: LottoGame) -> String {
        switch game {
        case .lotto:
            return "Wtorki, czwartki i soboty o 22:00"
        case .miniLotto:
            return "Codziennie"
        case .eurojackpot:
            return "Wtorki i piątki"
        }
    }
    
    private func mockCouponPrice(for game: LottoGame) -> String {
        switch game {
        case .lotto:
            return "3 zł za zakład"
        case .miniLotto:
            return "1,50 zł za zakład"
        case .eurojackpot:
            return "12,50 zł za zakład"
        }
    }
}

// MARK: - Real API service

struct OpenLottoService: LottoService {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    
    private let historyDrawLimit = 12
    
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
        
        do {
            return try await fetchHistoricalDraws(for: game)
        } catch {
            print("Nie udało się pobrać większej historii, używam ostatnich wyników:", error)
            return try await fetchLastDrawsFallback(for: game)
        }
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
    
    func fetchGameInfo(for game: LottoGame) async throws -> LottoGameAPIInfo? {
        guard game.isImplemented else {
            throw LottoServiceError.unsupportedGame
        }
        
        let url = try makeURL(
            path: "lotteries/info",
            queryItems: [
                URLQueryItem(name: "gameType", value: apiGameType(for: game))
            ]
        )
        
        let response: APIGameInfoResponse = try await request(url)
        
        return LottoGameAPIInfo(
            game: game,
            nextDrawDate: response.nextDrawDate,
            closestPrizeValue: response.closestPrizeValue,
            draws: response.draws,
            couponPrice: response.couponPrice,
            closestPrizePoolType: response.closestPrizePoolType
        )
    }
    
    func fetchJackpotInfo(for game: LottoGame) async throws -> LottoJackpotAPIInfo? {
        guard game.isImplemented else {
            throw LottoServiceError.unsupportedGame
        }
        
        if game == .miniLotto {
            return nil
        }
        
        let url = try makeURL(
            path: "lotteries/info/game-jackpot",
            queryItems: [
                URLQueryItem(name: "gameType", value: apiGameType(for: game))
            ]
        )
        
        let response: APIJackpotResponse = try await request(url)
        
        return LottoJackpotAPIInfo(
            game: game,
            jackpotValue: response.jackpotValue,
            jackpotPlusValue: response.jackpotPlusValue,
            closestDraw: response.closestDraw
        )
    }
    
    // MARK: - Historical results
    
    private func fetchHistoricalDraws(for game: LottoGame) async throws -> [DrawResult] {
        let latestApiDraws = try await fetchLastResults(for: apiGameType(for: game))
        
        guard let latestDate = latestDrawDate(
            from: latestApiDraws,
            for: game
        ) else {
            throw LottoServiceError.noData
        }
        
        let dates = pastDrawDates(
            for: game,
            latestDrawDate: latestDate,
            count: historyDrawLimit
        )
        
        var allAPIDraws: [APIDrawResponse] = []
        
        for date in dates {
            do {
                let apiDraws = try await fetchResultsByDatePerGame(
                    apiGameType: apiGameType(for: game),
                    drawDate: date,
                    size: 10
                )
                
                allAPIDraws.append(contentsOf: apiDraws)
                
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch LottoServiceError.noData {
                continue
            } catch {
                print("Nie udało się pobrać losowania dla daty \(apiDateString(date)):", error)
                continue
            }
        }
        
        guard !allAPIDraws.isEmpty else {
            throw LottoServiceError.noData
        }
        
        switch game {
        case .lotto:
            let lottoDraws = allAPIDraws
                .filter { isLottoMainDraw($0) }
                .compactMap { apiDraw in
                    mapAPIDrawToDrawResult(apiDraw, fallbackGame: .lotto)
                }
            
            let plusDraws = allAPIDraws
                .filter { isLottoPlusDraw($0) }
                .compactMap { apiDraw in
                    mapLottoPlusDraw(apiDraw)
                }
            
            return mergeLottoWithPlus(
                lottoDraws: lottoDraws,
                plusDraws: plusDraws
            )
            .sorted { $0.drawDate > $1.drawDate }
            
        case .miniLotto:
            return allAPIDraws
                .filter { isAPIDraw($0, matching: .miniLotto) }
                .compactMap { apiDraw in
                    mapAPIDrawToDrawResult(apiDraw, fallbackGame: .miniLotto)
                }
                .sorted { $0.drawDate > $1.drawDate }
            
        case .eurojackpot:
            return allAPIDraws
                .filter { isAPIDraw($0, matching: .eurojackpot) }
                .compactMap { apiDraw in
                    mapAPIDrawToDrawResult(apiDraw, fallbackGame: .eurojackpot)
                }
                .sorted { $0.drawDate > $1.drawDate }
        }
    }
    
    private func fetchResultsByDatePerGame(
        apiGameType: String,
        drawDate: Date,
        size: Int
    ) async throws -> [APIDrawResponse] {
        let url = try makeURL(
            path: "lotteries/draw-results/by-date-per-game",
            queryItems: [
                URLQueryItem(name: "gameType", value: apiGameType),
                URLQueryItem(name: "drawDate", value: apiDateString(drawDate)),
                URLQueryItem(name: "index", value: "1"),
                URLQueryItem(name: "size", value: "\(size)"),
                URLQueryItem(name: "sort", value: "drawDate"),
                URLQueryItem(name: "order", value: "DESC")
            ]
        )
        
        let response: APIDrawsListResponse = try await request(url)
        return response.items
    }
    
    // MARK: - Last results fallback
    
    private func fetchLastDrawsFallback(for game: LottoGame) async throws -> [DrawResult] {
        let apiDraws = try await fetchLastResults(for: apiGameType(for: game))
        
        switch game {
        case .lotto:
            let lottoDraws = apiDraws
                .filter { isLottoMainDraw($0) }
                .compactMap { apiDraw in
                    mapAPIDrawToDrawResult(apiDraw, fallbackGame: .lotto)
                }
            
            let plusDraws = apiDraws
                .filter { isLottoPlusDraw($0) }
                .compactMap { apiDraw in
                    mapLottoPlusDraw(apiDraw)
                }
            
            return mergeLottoWithPlus(
                lottoDraws: lottoDraws,
                plusDraws: plusDraws
            )
            .sorted { $0.drawDate > $1.drawDate }
            
        case .miniLotto:
            return apiDraws
                .filter { isAPIDraw($0, matching: .miniLotto) }
                .compactMap { apiDraw in
                    mapAPIDrawToDrawResult(apiDraw, fallbackGame: .miniLotto)
                }
                .sorted { $0.drawDate > $1.drawDate }
            
        case .eurojackpot:
            return apiDraws
                .filter { isAPIDraw($0, matching: .eurojackpot) }
                .compactMap { apiDraw in
                    mapAPIDrawToDrawResult(apiDraw, fallbackGame: .eurojackpot)
                }
                .sorted { $0.drawDate > $1.drawDate }
        }
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
    
    // MARK: - Next draw
    
    private func fetchNextDrawDate(for game: LottoGame) async throws -> Date? {
        let url = try makeURL(
            path: "lotteries/info/next-draw",
            queryItems: [
                URLQueryItem(name: "gameType", value: apiGameType(for: game))
            ]
        )
        
        let response: APINextDrawResponse = try await request(url)
        return response.nextDrawDate
    }
    
    // MARK: - Request
    
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
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LottoServiceError.unauthorized
        }
        
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
        
        if httpResponse.statusCode == 404 {
            throw LottoServiceError.noData
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("LOTTO API status code:", httpResponse.statusCode)
            if let body = String(data: data, encoding: .utf8) {
                print("LOTTO API body:", body)
            }
            throw LottoServiceError.invalidResponse
        }
        
        let contentType = httpResponse.value(forHTTPHeaderField: "content-type") ?? ""
        
        if !contentType.lowercased().contains("application/json") {
            print("LOTTO API zwróciło odpowiedź inną niż JSON:", contentType)
            
            if let body = String(data: data, encoding: .utf8) {
                print("LOTTO API body:", body)
            }
            
            throw LottoServiceError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                if let date = ISO8601DateFormatter.lottoWithFractionalSeconds.date(from: dateString) {
                    return date
                }
                
                if let date = ISO8601DateFormatter.lotto.date(from: dateString) {
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
            print("Błąd dekodowania API:", error)
            if let body = String(data: data, encoding: .utf8) {
                print("LOTTO API body:", body)
            }
            throw LottoServiceError.decodingFailed
        }
    }
    
    // MARK: - Mapping
    
    private func mapAPIDrawToDrawResult(
        _ apiDraw: APIDrawResponse,
        fallbackGame: LottoGame
    ) -> DrawResult? {
        let firstResult = apiDraw.results?.first
        
        let apiGameName = firstResult?.gameType ?? apiDraw.gameType
        let game = apiGameName.flatMap { LottoGame.fromAPIName($0) } ?? fallbackGame
        
        let drawDate = firstResult?.drawDate ?? apiDraw.drawDate
        let numbers = (firstResult?.resultsJson ?? []).sorted()
        let specialResults = (firstResult?.specialResults ?? []).sorted()
        
        guard let drawDate, !numbers.isEmpty else {
            return nil
        }
        
        switch game {
        case .eurojackpot:
            return DrawResult(
                game: .eurojackpot,
                drawDate: drawDate,
                numbers: numbers,
                extraNumbers: specialResults
            )
            
        case .lotto:
            return DrawResult(
                game: .lotto,
                drawDate: drawDate,
                numbers: numbers
            )
            
        case .miniLotto:
            return DrawResult(
                game: .miniLotto,
                drawDate: drawDate,
                numbers: numbers
            )
        }
    }
    
    private func mapLottoPlusDraw(_ apiDraw: APIDrawResponse) -> DrawResult? {
        let firstResult = apiDraw.results?.first
        
        let drawDate = firstResult?.drawDate ?? apiDraw.drawDate
        let numbers = (firstResult?.resultsJson ?? []).sorted()
        
        guard let drawDate, !numbers.isEmpty else {
            return nil
        }
        
        return DrawResult(
            game: .lotto,
            drawDate: drawDate,
            numbers: numbers
        )
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
                numbers: lottoDraw.numbers.sorted(),
                plusNumbers: matchingPlusDraw?.numbers.sorted(),
                extraNumbers: lottoDraw.extraNumbers?.sorted()
            )
        }
    }
    
    // MARK: - History date generation
    
    private func latestDrawDate(
        from apiDraws: [APIDrawResponse],
        for game: LottoGame
    ) -> Date? {
        let matchingDraws: [APIDrawResponse]
        
        switch game {
        case .lotto:
            matchingDraws = apiDraws.filter { isLottoMainDraw($0) }
        case .miniLotto:
            matchingDraws = apiDraws.filter { isAPIDraw($0, matching: .miniLotto) }
        case .eurojackpot:
            matchingDraws = apiDraws.filter { isAPIDraw($0, matching: .eurojackpot) }
        }
        
        return matchingDraws
            .compactMap { apiDraw in
                apiDraw.results?.first?.drawDate ?? apiDraw.drawDate
            }
            .max()
    }
    
    private func pastDrawDates(
        for game: LottoGame,
        latestDrawDate: Date,
        count: Int
    ) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        
        let latestTime = calendar.dateComponents(
            [.hour, .minute, .second],
            from: latestDrawDate
        )
        
        var currentDay = calendar.startOfDay(for: latestDrawDate)
        var dates: [Date] = []
        
        while dates.count < count {
            if isDrawDay(currentDay, for: game, calendar: calendar) {
                var components = calendar.dateComponents(
                    [.year, .month, .day],
                    from: currentDay
                )
                
                components.hour = latestTime.hour ?? 22
                components.minute = latestTime.minute ?? 0
                components.second = latestTime.second ?? 0
                
                if let date = calendar.date(from: components) {
                    dates.append(date)
                }
            }
            
            guard let previousDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: currentDay
            ) else {
                break
            }
            
            currentDay = previousDay
        }
        
        return dates
    }
    
    private func isDrawDay(
        _ date: Date,
        for game: LottoGame,
        calendar: Calendar
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        
        switch game {
        case .lotto:
            return [3, 5, 7].contains(weekday) // wtorek, czwartek, sobota
        case .miniLotto:
            return true
        case .eurojackpot:
            return [3, 6].contains(weekday) // wtorek, piątek
        }
    }
    
    // MARK: - Helpers
    
    private func apiGameType(for game: LottoGame) -> String {
        switch game {
        case .lotto:
            return "Lotto"
        case .miniLotto:
            return "MiniLotto"
        case .eurojackpot:
            return "EuroJackpot"
        }
    }
    
    private func isAPIDraw(
        _ apiDraw: APIDrawResponse,
        matching game: LottoGame
    ) -> Bool {
        normalizedGameType(from: apiDraw) == normalized(apiGameType(for: game))
    }
    
    private func isLottoMainDraw(_ apiDraw: APIDrawResponse) -> Bool {
        normalizedGameType(from: apiDraw) == normalized("Lotto")
    }
    
    private func isLottoPlusDraw(_ apiDraw: APIDrawResponse) -> Bool {
        normalizedGameType(from: apiDraw) == normalized("LottoPlus")
    }
    
    private func normalizedGameType(from apiDraw: APIDrawResponse) -> String {
        normalized(apiDraw.results?.first?.gameType ?? apiDraw.gameType ?? "")
    }
    
    private func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
    
    private func apiDateString(_ date: Date) -> String {
        ISO8601DateFormatter.apiQueryDate.string(from: date)
    }
}

// MARK: - API DTO

private struct APIDrawsListResponse: Decodable {
    let items: [APIDrawResponse]
    
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        
        if let container,
           let decodedItems = try? container.decode([APIDrawResponse].self, forKey: .items) {
            self.items = decodedItems
            return
        }
        
        if let container,
           let decodedData = try? container.decode([APIDrawResponse].self, forKey: .data) {
            self.items = decodedData
            return
        }
        
        if let container,
           let decodedResults = try? container.decode([APIDrawResponse].self, forKey: .results) {
            self.items = decodedResults
            return
        }
        
        if let array = try? [APIDrawResponse](from: decoder) {
            self.items = array
            return
        }
        
        if let single = try? APIDrawResponse(from: decoder),
           single.drawDate != nil || single.gameType != nil || single.results != nil {
            self.items = [single]
            return
        }
        
        self.items = []
    }
    
    private enum CodingKeys: String, CodingKey {
        case items
        case data
        case results
    }
}

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

private struct APIGameInfoResponse: Decodable {
    let gameType: String?
    let nextDrawDate: Date?
    let closestPrizeValue: Double?
    let draws: String?
    let couponPrice: String?
    let closestPrizePoolType: String?
}

private struct APIJackpotResponse: Decodable {
    let jackpotValue: Double?
    let jackpotPlusValue: Double?
    let closestDraw: Date?
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
    
    static let apiQueryDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime
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
