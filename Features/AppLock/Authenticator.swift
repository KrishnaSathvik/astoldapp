import Foundation
import LocalAuthentication

/// Abstraction over device-owner authentication so the lock state machine stays testable.
protocol Authenticating: Sendable {
    func authenticate(reason: String) async -> Bool
}

/// Real biometric/passcode authentication via LocalAuthentication (RULES.md §3, docs/06-tech-stack.md §12).
struct DeviceAuthenticator: Authenticating {
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        // Biometric-first, with system passcode fallback.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
