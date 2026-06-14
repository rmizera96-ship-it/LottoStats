import Foundation

enum LottoServiceError: Error, LocalizedError {
    case unsupportedGame
    case noData
    case invalidURL
    case invalidResponse
    case unauthorized
    case decodingFailed
    case temporarilyUnavailable
    
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
        case .temporarilyUnavailable:
            return "Serwer LOTTO jest chwilowo niedostępny. Spróbuj ponownie za moment."
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

struct LottoFrequencyStats {
    let game: LottoGame
    let totalDraws: Int
    let mainNumbers: [LottoFrequencyItem]
    let specialNumbers: [LottoFrequencyItem]
    let dateFrom: Date
    let dateTo: Date
}

struct LottoFrequencyItem: Identifiable {
    var id: Int {
        number
    }
    
    let number: Int
    let numberOfOccurrences: Int
    let percentOfOccurrences: Double
}

struct LottoDrawPrizeInfo: Identifiable {
    var id: String {
        "\(gameType)-\(drawSystemId ?? 0)-\(drawDate?.timeIntervalSince1970 ?? 0)"
    }
    
    let gameType: String
    let drawDate: Date?
    let drawSystemId: Int?
    let ranks: [LottoPrizeRank]
}

struct LottoPrizeRank: Identifiable {
    var id: String {
        rank
    }
    
    let rank: String
    let winnersCount: Int
    let prizeValue: Double
}

struct LottoHighestWin: Identifiable {
    let id = UUID()
    let rank: String?
    let place: String?
    let address: String?
    let gameType: String
    let winDateUtc: Date?
    let amountFixed: Double
    let onlineWin: Bool
}

extension LottoHighestWin {
    static let samples: [LottoHighestWin] = [
        LottoHighestWin(
            rank: "I (5+2)",
            place: "pow. krotoszyński",
            address: "-",
            gameType: "EuroJackpot",
            winDateUtc: Calendar.current.date(from: DateComponents(year: 2022, month: 8, day: 12)),
            amountFixed: 213_584_986,
            onlineWin: false
        ),
        LottoHighestWin(
            rank: "I (5+2)",
            place: "pow. bieruńsko-lędziński",
            address: "-",
            gameType: "EuroJackpot",
            winDateUtc: Calendar.current.date(from: DateComponents(year: 2021, month: 8, day: 13)),
            amountFixed: 206_550_000,
            onlineWin: false
        ),
        LottoHighestWin(
            rank: "brak",
            place: "Skrzyszów",
            address: "Skrzyszów 27c",
            gameType: "Lotto",
            winDateUtc: Calendar.current.date(from: DateComponents(year: 2017, month: 3, day: 16)),
            amountFixed: 36_726_210.20,
            onlineWin: false
        )
    ]
}

protocol LottoService {
    func fetchDraws(for game: LottoGame) async throws -> [DrawResult]
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult?
    func fetchUpcomingDrawDates(for game: LottoGame, count: Int) async throws -> [Date]
    func fetchGameInfo(for game: LottoGame) async throws -> LottoGameAPIInfo?
    func fetchJackpotInfo(for game: LottoGame) async throws -> LottoJackpotAPIInfo?
    func fetchNumberFrequencyStats(for game: LottoGame) async throws -> LottoFrequencyStats?
    func fetchDrawPrizes(for draw: DrawResult) async throws -> [LottoDrawPrizeInfo]
    func fetchHighestWins(limit: Int) async throws -> [LottoHighestWin]
}

extension LottoService {
    func fetchGameInfo(for game: LottoGame) async throws -> LottoGameAPIInfo? {
        nil
    }
    
    func fetchJackpotInfo(for game: LottoGame) async throws -> LottoJackpotAPIInfo? {
        nil
    }
    
    func fetchNumberFrequencyStats(for game: LottoGame) async throws -> LottoFrequencyStats? {
        nil
    }
    
    func fetchDrawPrizes(for draw: DrawResult) async throws -> [LottoDrawPrizeInfo] {
        []
    }
    
    func fetchHighestWins(limit: Int) async throws -> [LottoHighestWin] {
        Array(LottoHighestWin.samples.prefix(limit))
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
    
    func fetchNumberFrequencyStats(for game: LottoGame) async throws -> LottoFrequencyStats? {
        try await simulateNetworkDelay()
        
        let draws = DrawResult.samples
            .filter { $0.game == game }
        
        guard !draws.isEmpty else {
            return nil
        }
        
        let mainNumbers = draws.flatMap { $0.numbers }
        let specialNumbers = draws.flatMap { $0.extraNumbers ?? [] }
        let sortedDates = draws.map { $0.drawDate }.sorted()
        
        return LottoFrequencyStats(
            game: game,
            totalDraws: draws.count,
            mainNumbers: frequencyItems(from: mainNumbers, totalDraws: draws.count),
            specialNumbers: frequencyItems(from: specialNumbers, totalDraws: draws.count),
            dateFrom: sortedDates.first ?? Date(),
            dateTo: sortedDates.last ?? Date()
        )
    }
    
    func fetchDrawPrizes(for draw: DrawResult) async throws -> [LottoDrawPrizeInfo] {
        try await simulateNetworkDelay()
        
        return [
            LottoDrawPrizeInfo(
                gameType: draw.game.displayName,
                drawDate: draw.drawDate,
                drawSystemId: draw.drawSystemId,
                ranks: [
                    LottoPrizeRank(rank: "1", winnersCount: 0, prizeValue: 0),
                    LottoPrizeRank(rank: "2", winnersCount: 12, prizeValue: 3500),
                    LottoPrizeRank(rank: "3", winnersCount: 240, prizeValue: 120),
                    LottoPrizeRank(rank: "4", winnersCount: 1800, prizeValue: 24)
                ]
            )
        ]
    }
    
    func fetchHighestWins(limit: Int) async throws -> [LottoHighestWin] {
        try await simulateNetworkDelay()
        return Array(LottoHighestWin.samples.prefix(limit))
    }
    
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func sortedDraw(_ draw: DrawResult) -> DrawResult {
        DrawResult(
            drawSystemId: draw.drawSystemId,
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
    
    private func frequencyItems(from numbers: [Int], totalDraws: Int) -> [LottoFrequencyItem] {
        let grouped = Dictionary(grouping: numbers, by: { $0 })
        
        return grouped
            .map { number, values in
                let occurrences = values.count
                let percent = totalDraws > 0
                    ? (Double(occurrences) / Double(totalDraws) * 100.0).rounded()
                    : 0
                
                return LottoFrequencyItem(
                    number: number,
                    numberOfOccurrences: occurrences,
                    percentOfOccurrences: percent
                )
            }
            .sorted { first, second in
                if first.numberOfOccurrences == second.numberOfOccurrences {
                    return first.number < second.number
                }
                
                return first.numberOfOccurrences > second.numberOfOccurrences
            }
    }
}

// MARK: - Shared request coordination

private actor LottoAPIRequestCoordinator {
    static let shared = LottoAPIRequestCoordinator()

    private var inFlightRequests: [URL: Task<(Data, HTTPURLResponse), Error>] = [:]
    private var nextAllowedRequestStart = Date.distantPast
    private let minimumRequestSpacing: TimeInterval = 0.18

    func data(
        for request: URLRequest,
        using session: URLSession
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else {
            throw LottoServiceError.invalidURL
        }

        if let existingTask = inFlightRequests[url] {
            return try await existingTask.value
        }

        let now = Date()
        let scheduledStart = max(now, nextAllowedRequestStart)
        nextAllowedRequestStart = scheduledStart.addingTimeInterval(minimumRequestSpacing)
        let delay = max(0, scheduledStart.timeIntervalSince(now))

        let task = Task<(Data, HTTPURLResponse), Error> {
            if delay > 0 {
                try await Task.sleep(
                    nanoseconds: UInt64(delay * 1_000_000_000)
                )
            }

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LottoServiceError.invalidResponse
            }

            return (data, httpResponse)
        }

        inFlightRequests[url] = task

        defer {
            inFlightRequests[url] = nil
        }

        return try await task.value
    }
}

private enum LottoAPIRequestFailure: Error {
    case transientStatus(code: Int, retryAfter: TimeInterval?)
    case unexpectedContentType(String)
    case decoding(Error)
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
            AppLogger.debug("Nie udało się pobrać większej historii, używam ostatnich wyników:", error)
            return try await fetchLastDrawsFallback(for: game)
        }
    }
    
    func fetchLatestDraw(for game: LottoGame) async throws -> DrawResult? {
        guard game.isImplemented else {
            throw LottoServiceError.unsupportedGame
        }
        
        return try await fetchLastDrawsFallback(for: game).first
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
    
    func fetchNumberFrequencyStats(for game: LottoGame) async throws -> LottoFrequencyStats? {
        guard game.isImplemented else {
            throw LottoServiceError.unsupportedGame
        }
        
        let dateRange = statisticsDateRange()
        
        let url = try makeURL(
            path: "lotteries/draw-statistics/numbers-frequency",
            queryItems: [
                URLQueryItem(name: "gameType", value: apiGameType(for: game)),
                URLQueryItem(name: "dateFrom", value: apiDateString(dateRange.from)),
                URLQueryItem(name: "dateTo", value: apiDateString(dateRange.to))
            ]
        )
        
        let response: APINumberFrequencyResponse = try await request(
            url,
            validate: { response in
                (response.totalDraws ?? 0) > 0
                    && !(response.numberFrequrency ?? []).isEmpty
            }
        )
        
        let mainNumbers = (response.numberFrequrency ?? [])
            .compactMap { item -> LottoFrequencyItem? in
                guard let number = item.number,
                      let occurrences = item.numberOfOccurrences else {
                    return nil
                }
                
                return LottoFrequencyItem(
                    number: number,
                    numberOfOccurrences: occurrences,
                    percentOfOccurrences: item.percentOfOccurrences ?? 0
                )
            }
            .sorted { first, second in
                if first.numberOfOccurrences == second.numberOfOccurrences {
                    return first.number < second.number
                }
                
                return first.numberOfOccurrences > second.numberOfOccurrences
            }
        
        let specialNumbers = (response.numberSpecialFrequrency ?? [])
            .compactMap { item -> LottoFrequencyItem? in
                guard let number = item.number,
                      let occurrences = item.numberOfOccurrences else {
                    return nil
                }
                
                return LottoFrequencyItem(
                    number: number,
                    numberOfOccurrences: occurrences,
                    percentOfOccurrences: item.percentOfOccurrences ?? 0
                )
            }
            .sorted { first, second in
                if first.numberOfOccurrences == second.numberOfOccurrences {
                    return first.number < second.number
                }
                
                return first.numberOfOccurrences > second.numberOfOccurrences
            }
        
        return LottoFrequencyStats(
            game: game,
            totalDraws: response.totalDraws ?? 0,
            mainNumbers: mainNumbers,
            specialNumbers: specialNumbers,
            dateFrom: dateRange.from,
            dateTo: dateRange.to
        )
    }
    
    func fetchDrawPrizes(for draw: DrawResult) async throws -> [LottoDrawPrizeInfo] {
        guard let drawSystemId = draw.drawSystemId else {
            return []
        }
        
        let url = try makeURL(
            path: "lotteries/draw-prizes/\(apiGameType(for: draw.game))/\(drawSystemId)",
            queryItems: []
        )
        
        let response: [APIDrawPrizesResponse] = try await request(url)
        
        return response.compactMap { apiPrizeInfo in
            let ranks = (apiPrizeInfo.prizes ?? [:])
                .map { rank, prize in
                    LottoPrizeRank(
                        rank: rank,
                        winnersCount: prize.prize ?? 0,
                        prizeValue: prize.prizeValue ?? 0
                    )
                }
                .sorted { first, second in
                    let firstRank = Int(first.rank) ?? 999
                    let secondRank = Int(second.rank) ?? 999
                    return firstRank < secondRank
                }
            
            guard !ranks.isEmpty else {
                return nil
            }
            
            return LottoDrawPrizeInfo(
                gameType: apiPrizeInfo.gameType ?? draw.game.displayName,
                drawDate: apiPrizeInfo.drawDate,
                drawSystemId: apiPrizeInfo.drawSystemId,
                ranks: ranks
            )
        }
    }
    
    func fetchHighestWins(limit: Int) async throws -> [LottoHighestWin] {
        let url = try makeURL(
            path: "lotteries/highest-wins",
            queryItems: [
                URLQueryItem(name: "index", value: "1"),
                URLQueryItem(name: "size", value: "\(limit)"),
                URLQueryItem(name: "sort", value: "winDateUtc"),
                URLQueryItem(name: "order", value: "DESC")
            ]
        )
        
        let response: APIHighestWinsResponse = try await request(url)
        
        return response.items.map { item in
            LottoHighestWin(
                rank: item.rank,
                place: item.place,
                address: item.address,
                gameType: item.gameType ?? "Nieznana gra",
                winDateUtc: item.winDateUtc,
                amountFixed: item.amountFixed ?? 0,
                onlineWin: item.onlineWin ?? false
            )
        }
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
            } catch LottoServiceError.noData {
                continue
            } catch {
                AppLogger.debug("Nie udało się pobrać losowania dla daty", apiDateString(date), error)
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
        
        let response: [APIDrawResponse] = try await request(
            url,
            validate: { !$0.isEmpty }
        )
        return response
    }
    
    private func fetchNextDrawDate(for game: LottoGame) async throws -> Date? {
        let url = try makeURL(
            path: "lotteries/info/next-draw",
            queryItems: [
                URLQueryItem(name: "gameType", value: apiGameType(for: game))
            ]
        )
        
        let response: APINextDrawResponse = try await request(
            url,
            validate: { $0.nextDrawDate != nil }
        )
        return response.nextDrawDate
    }
    
    // MARK: - Request + cache
    
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
    
    private func request<T: Decodable>(
        _ url: URL,
        validate: (T) -> Bool = { _ in true }
    ) async throws -> T {
        let maxCacheAge = cacheMaxAge(for: url)

        if let cachedData = LottoAPICache.shared.load(
            for: url,
            maxAge: maxCacheAge
        ) {
            do {
                let decoded = try decodeResponse(T.self, from: cachedData)

                guard validate(decoded) else {
                    throw LottoServiceError.decodingFailed
                }

                return decoded
            } catch {
                AppLogger.debug("Nie udało się odczytać świeżego cache, pobieram z API:", error)
            }
        }

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LottoServiceError.unauthorized
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "secret")

        let maximumAttempts = 3
        var finalError: Error = LottoServiceError.temporarilyUnavailable

        for attempt in 1...maximumAttempts {
            do {
                let (data, httpResponse) = try await LottoAPIRequestCoordinator.shared.data(
                    for: urlRequest,
                    using: session
                )

                if httpResponse.statusCode == 401 {
                    throw LottoServiceError.unauthorized
                }

                if httpResponse.statusCode == 404 {
                    throw LottoServiceError.noData
                }

                if isTransientStatusCode(httpResponse.statusCode) {
                    throw LottoAPIRequestFailure.transientStatus(
                        code: httpResponse.statusCode,
                        retryAfter: retryAfterDelay(from: httpResponse)
                    )
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    logUnexpectedResponse(
                        data: data,
                        response: httpResponse,
                        url: url
                    )
                    throw LottoServiceError.invalidResponse
                }

                let contentType = httpResponse.value(
                    forHTTPHeaderField: "content-type"
                ) ?? ""

                guard contentType.lowercased().contains("application/json") else {
                    logUnexpectedResponse(
                        data: data,
                        response: httpResponse,
                        url: url
                    )
                    throw LottoAPIRequestFailure.unexpectedContentType(contentType)
                }

                do {
                    let decoded = try decodeResponse(T.self, from: data)

                    guard validate(decoded) else {
                        throw LottoAPIRequestFailure.decoding(
                            LottoServiceError.decodingFailed
                        )
                    }

                    LottoAPICache.shared.save(data, for: url)
                    return decoded
                } catch {
                    logUnexpectedResponse(
                        data: data,
                        response: httpResponse,
                        url: url
                    )
                    throw LottoAPIRequestFailure.decoding(error)
                }
            } catch {
                finalError = publicError(from: error)

                guard attempt < maximumAttempts, shouldRetry(error) else {
                    break
                }

                let delay = retryDelay(
                    after: error,
                    attempt: attempt
                )

                AppLogger.debug(
                    "Ponawiam zapytanie LOTTO (próba \(attempt + 1)/\(maximumAttempts)) za \(delay)s:",
                    url.absoluteString
                )

                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(delay * 1_000_000_000)
                    )
                } catch {
                    throw error
                }
            }
        }

        if let staleData = LottoAPICache.shared.load(
            for: url,
            maxAge: maxCacheAge,
            allowExpired: true
        ) {
            do {
                AppLogger.debug("API niedostępne, używam starego cache dla:", url.absoluteString)
                let decoded = try decodeResponse(T.self, from: staleData)

                guard validate(decoded) else {
                    throw LottoServiceError.decodingFailed
                }

                return decoded
            } catch {
                AppLogger.debug("Nie udało się odczytać starego cache:", error)
            }
        }

        throw finalError
    }

    private func isTransientStatusCode(_ statusCode: Int) -> Bool {
        statusCode == 408
            || statusCode == 425
            || statusCode == 429
            || (500...599).contains(statusCode)
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if error is CancellationError {
            return false
        }

        if let serviceError = error as? LottoServiceError {
            switch serviceError {
            case .unauthorized, .noData, .unsupportedGame, .invalidURL:
                return false
            case .invalidResponse, .decodingFailed, .temporarilyUnavailable:
                return true
            }
        }

        if error is LottoAPIRequestFailure {
            return true
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled, .badURL, .unsupportedURL, .userAuthenticationRequired:
                return false
            default:
                return true
            }
        }

        return false
    }

    private func retryDelay(
        after error: Error,
        attempt: Int
    ) -> TimeInterval {
        if let requestError = error as? LottoAPIRequestFailure,
           case let .transientStatus(_, retryAfter) = requestError,
           let retryAfter {
            return min(max(retryAfter, 0.5), 5)
        }

        return attempt == 1 ? 0.6 : 1.2
    }

    private func retryAfterDelay(
        from response: HTTPURLResponse
    ) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        return TimeInterval(value)
    }

    private func publicError(from error: Error) -> Error {
        if let serviceError = error as? LottoServiceError {
            return serviceError
        }

        if let requestError = error as? LottoAPIRequestFailure,
           case .decoding = requestError {
            return LottoServiceError.decodingFailed
        }

        if error is LottoAPIRequestFailure || error is URLError {
            return LottoServiceError.temporarilyUnavailable
        }

        return error
    }

    private func logUnexpectedResponse(
        data: Data,
        response: HTTPURLResponse,
        url: URL
    ) {
        AppLogger.debug(
            "LOTTO API nieoczekiwana odpowiedź [\(response.statusCode)] dla:",
            url.absoluteString
        )

        if let body = String(data: data, encoding: .utf8) {
            AppLogger.debug("LOTTO API body:", String(body.prefix(800)))
        }
    }

    private func decodeResponse<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {
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
    }
    
    private func cacheMaxAge(for url: URL) -> TimeInterval {
        let path = url.path.lowercased()
        
        // Wynik dla konkretnej, historycznej daty praktycznie się nie zmienia.
        if path.contains("draw-results/by-date-per-game") {
            return 7 * 24 * 60 * 60
        }
        
        // Najnowsze wyniki sprawdzamy częściej, ale nie przy każdym wejściu.
        if path.contains("draw-results/last-results-per-game") {
            return 30 * 60
        }
        
        if path.contains("draw-prizes") {
            return 30 * 24 * 60 * 60
        }
        
        if path.contains("numbers-frequency") {
            return 24 * 60 * 60
        }
        
        if path.contains("highest-wins") {
            return 24 * 60 * 60
        }
        
        if path.contains("lotteries/info") {
            return 30 * 60
        }
        
        return 60 * 60
    }
    
    // MARK: - Mapping
    
    private func mapAPIDrawToDrawResult(
        _ apiDraw: APIDrawResponse,
        fallbackGame: LottoGame
    ) -> DrawResult? {
        let firstResult = apiDraw.results?.first
        
        let apiGameName = firstResult?.gameType ?? apiDraw.gameType
        let game = apiGameName.flatMap { LottoGame.fromAPIName($0) } ?? fallbackGame
        
        let drawSystemId = firstResult?.drawSystemId ?? apiDraw.drawSystemId
        let drawDate = firstResult?.drawDate ?? apiDraw.drawDate
        let numbers = (firstResult?.resultsJson ?? []).sorted()
        let specialResults = (firstResult?.specialResults ?? []).sorted()
        
        guard let drawDate, !numbers.isEmpty else {
            return nil
        }
        
        switch game {
        case .eurojackpot:
            return DrawResult(
                drawSystemId: drawSystemId,
                game: .eurojackpot,
                drawDate: drawDate,
                numbers: numbers,
                extraNumbers: specialResults
            )
            
        case .lotto:
            return DrawResult(
                drawSystemId: drawSystemId,
                game: .lotto,
                drawDate: drawDate,
                numbers: numbers
            )
            
        case .miniLotto:
            return DrawResult(
                drawSystemId: drawSystemId,
                game: .miniLotto,
                drawDate: drawDate,
                numbers: numbers
            )
        }
    }
    
    private func mapLottoPlusDraw(_ apiDraw: APIDrawResponse) -> DrawResult? {
        let firstResult = apiDraw.results?.first
        
        let drawSystemId = firstResult?.drawSystemId ?? apiDraw.drawSystemId
        let drawDate = firstResult?.drawDate ?? apiDraw.drawDate
        let numbers = (firstResult?.resultsJson ?? []).sorted()
        
        guard let drawDate, !numbers.isEmpty else {
            return nil
        }
        
        return DrawResult(
            drawSystemId: drawSystemId,
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
                drawSystemId: lottoDraw.drawSystemId,
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
            return [3, 5, 7].contains(weekday)
        case .miniLotto:
            return true
        case .eurojackpot:
            return [3, 6].contains(weekday)
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
    
    private func statisticsDateRange() -> (from: Date, to: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        
        let from = calendar.date(
            from: DateComponents(
                year: currentYear - 1,
                month: 1,
                day: 1,
                hour: 0,
                minute: 0,
                second: 0
            )
        ) ?? now
        
        let startOfToday = calendar.startOfDay(for: now)
        let to = calendar.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: startOfToday
        ) ?? now
        
        return (from, to)
    }
}

// MARK: - API DTO

private struct APIDrawsListResponse: Decodable {
    let items: [APIDrawResponse]

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if container.contains(.items) {
                self.items = try container.decode([APIDrawResponse].self, forKey: .items)
                return
            }

            if container.contains(.data) {
                self.items = try container.decode([APIDrawResponse].self, forKey: .data)
                return
            }

            if container.contains(.results) {
                self.items = try container.decode([APIDrawResponse].self, forKey: .results)
                return
            }

            if container.allKeys.isEmpty {
                self.items = []
                return
            }
        }

        if let array = try? [APIDrawResponse](from: decoder) {
            self.items = array
            return
        }

        if let single = try? APIDrawResponse(from: decoder) {
            self.items = [single]
            return
        }

        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Odpowiedź nie zawiera listy losowań."
            )
        )
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        drawSystemId = try container.decodeIfPresent(Int.self, forKey: .drawSystemId)
        drawDate = try container.decodeIfPresent(Date.self, forKey: .drawDate)
        gameType = try container.decodeIfPresent(String.self, forKey: .gameType)
        multiplierValue = try container.decodeIfPresent(Int.self, forKey: .multiplierValue)
        results = try container.decodeIfPresent([APIDrawResult].self, forKey: .results)
        showSpecialResults = try container.decodeIfPresent(Bool.self, forKey: .showSpecialResults)
        isNewEuroJackpotDraw = try container.decodeIfPresent(Bool.self, forKey: .isNewEuroJackpotDraw)

        guard drawSystemId != nil
                || drawDate != nil
                || gameType != nil
                || results != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Element nie zawiera danych losowania."
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case drawSystemId
        case drawDate
        case gameType
        case multiplierValue
        case results
        case showSpecialResults
        case isNewEuroJackpotDraw
    }
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameType = try container.decodeIfPresent(String.self, forKey: .gameType)
        closestPrizeValue = try container.decodeIfPresent(Double.self, forKey: .closestPrizeValue)
        nextDrawDate = try container.decodeIfPresent(Date.self, forKey: .nextDrawDate)
        playSitePath = try container.decodeIfPresent(String.self, forKey: .playSitePath)

        guard gameType != nil || nextDrawDate != nil || closestPrizeValue != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Odpowiedź nie zawiera terminu kolejnego losowania."
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case gameType
        case closestPrizeValue
        case nextDrawDate
        case playSitePath
    }
}

private struct APIGameInfoResponse: Decodable {
    let gameType: String?
    let nextDrawDate: Date?
    let closestPrizeValue: Double?
    let draws: String?
    let couponPrice: String?
    let closestPrizePoolType: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameType = try container.decodeIfPresent(String.self, forKey: .gameType)
        nextDrawDate = try container.decodeIfPresent(Date.self, forKey: .nextDrawDate)
        closestPrizeValue = try container.decodeIfPresent(Double.self, forKey: .closestPrizeValue)
        draws = try container.decodeIfPresent(String.self, forKey: .draws)
        couponPrice = try container.decodeIfPresent(String.self, forKey: .couponPrice)
        closestPrizePoolType = try container.decodeIfPresent(String.self, forKey: .closestPrizePoolType)

        guard gameType != nil
                || nextDrawDate != nil
                || closestPrizeValue != nil
                || draws != nil
                || couponPrice != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Odpowiedź nie zawiera informacji o grze."
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case gameType
        case nextDrawDate
        case closestPrizeValue
        case draws
        case couponPrice
        case closestPrizePoolType
    }
}

private struct APIJackpotResponse: Decodable {
    let jackpotValue: Double?
    let jackpotPlusValue: Double?
    let closestDraw: Date?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jackpotValue = try container.decodeIfPresent(Double.self, forKey: .jackpotValue)
        jackpotPlusValue = try container.decodeIfPresent(Double.self, forKey: .jackpotPlusValue)
        closestDraw = try container.decodeIfPresent(Date.self, forKey: .closestDraw)

        guard jackpotValue != nil || jackpotPlusValue != nil || closestDraw != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Odpowiedź nie zawiera informacji o kumulacji."
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case jackpotValue
        case jackpotPlusValue
        case closestDraw
    }
}

private struct APINumberFrequencyResponse: Decodable {
    let totalDraws: Int?
    let numberFrequrency: [APINumberFrequencyItem]?
    let numberSpecialFrequrency: [APINumberFrequencyItem]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalDraws = try container.decodeIfPresent(Int.self, forKey: .totalDraws)
        numberFrequrency = try container.decodeIfPresent(
            [APINumberFrequencyItem].self,
            forKey: .numberFrequrency
        )
        numberSpecialFrequrency = try container.decodeIfPresent(
            [APINumberFrequencyItem].self,
            forKey: .numberSpecialFrequrency
        )

        guard totalDraws != nil
                || numberFrequrency != nil
                || numberSpecialFrequrency != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Odpowiedź nie zawiera statystyk liczb."
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case totalDraws
        case numberFrequrency
        case numberSpecialFrequrency
    }
}

private struct APINumberFrequencyItem: Decodable {
    let number: Int?
    let numberOfOccurrences: Int?
    let percentOfOccurrences: Double?
}

private struct APIDrawPrizesResponse: Decodable {
    let prizes: [String: APIPrizeRankResponse]?
    let drawDate: Date?
    let drawSystemId: Int?
    let gameType: String?
    let prizesEmpty: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prizes = try container.decodeIfPresent(
            [String: APIPrizeRankResponse].self,
            forKey: .prizes
        )
        drawDate = try container.decodeIfPresent(Date.self, forKey: .drawDate)
        drawSystemId = try container.decodeIfPresent(Int.self, forKey: .drawSystemId)
        gameType = try container.decodeIfPresent(String.self, forKey: .gameType)
        prizesEmpty = try container.decodeIfPresent(Bool.self, forKey: .prizesEmpty)

        guard prizes != nil
                || drawDate != nil
                || drawSystemId != nil
                || gameType != nil
                || prizesEmpty != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Odpowiedź nie zawiera danych o wygranych."
                )
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case prizes
        case drawDate
        case drawSystemId
        case gameType
        case prizesEmpty
    }
}

private struct APIPrizeRankResponse: Decodable {
    let prize: Int?
    let prizeValue: Double?
}

private struct APIHighestWinsResponse: Decodable {
    let totalRows: Int?
    let items: [APIHighestWinItem]
    let meta: [String: String]?
    let code: Int?
}

private struct APIHighestWinItem: Decodable {
    let rank: String?
    let place: String?
    let address: String?
    let gameType: String?
    let winDateUtc: Date?
    let amountFixed: Double?
    let onlineWin: Bool?
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
