import Foundation

enum LottoAPIConfiguration {
    static let baseURL = URL(string: "https://developers.lotto.pl/api/open/v1")!
    
    // Nie wrzucaj prawdziwego klucza API na GitHuba.
    // Na razie zostaw puste. Aplikacja będzie wtedy używać danych testowych.
    static let apiKey = ""
    
    static var shouldUseRealAPI: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
