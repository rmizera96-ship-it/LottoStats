import Foundation

enum AppLogger {
    static func debug(_ items: Any..., separator: String = " ") {
#if DEBUG
        Swift.print(items.map { String(describing: $0) }.joined(separator: separator))
#endif
    }
}
