import Foundation

public protocol RcloneOutputObserver: Sendable {
    func onLine(_ line: String) async
}
