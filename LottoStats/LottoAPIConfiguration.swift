import Foundation

enum LottoAPIConfiguration {
    static let baseURL = URL(string: "https://developers.lotto.pl/api/open/v1")!
    
    static var apiKey: String {
        guard let url = Bundle.main.url(
            forResource: "Secrets",
            withExtension: "plist"
        ) else {
            return ""
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return ""
        }
        
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any] else {
            return ""
        }
        
        guard let key = plist["LOTTO_API_KEY"] as? String else {
            return ""
        }
        
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static var shouldUseRealAPI: Bool {
        !apiKey.isEmpty
    }
}
