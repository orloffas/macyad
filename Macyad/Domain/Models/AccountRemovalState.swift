import Foundation

public struct AccountRemovalState: Equatable, Sendable {
    public let canRemove: Bool
    public let blockingPairNames: [String]
    public let inlineMessage: String?

    public init(
        canRemove: Bool,
        blockingPairNames: [String],
        inlineMessage: String?
    ) {
        self.canRemove = canRemove
        self.blockingPairNames = blockingPairNames
        self.inlineMessage = inlineMessage
    }
}
