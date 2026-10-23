import Foundation
import ShazamKit

/// A budget for one user-started listen, shared across replacement SDK sessions.
struct ShazamRecoveryPolicy {
    private var attempts = 0

    mutating func retryDelay(for error: Error) -> Duration? {
        guard attempts < 2, Self.isServiceFailure(error) else { return nil }
        attempts += 1
        return .seconds(attempts)
    }

    static func isServiceFailure(_ error: Error) -> Bool {
        var current = error as NSError
        // ShazamKit can wrap the service error, or return the Cocoa error itself.
        // Bound traversal because NSError userInfo can contain cyclic chains.
        for _ in 0..<8 {
            if current.domain == SHErrorDomain,
               current.code == SHError.Code.matchAttemptFailed.rawValue {
                return true
            }
            if current.domain == NSCocoaErrorDomain,
               current.code == CocoaError.Code.xpcConnectionInvalid.rawValue
                || current.code == CocoaError.Code.xpcConnectionInterrupted.rawValue {
                return true
            }
            guard let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError else { return false }
            current = underlying
        }
        return false
    }
}
