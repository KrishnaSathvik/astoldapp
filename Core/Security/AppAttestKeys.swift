import Foundation
import DeviceCheck

/// Seam over DeviceCheck's `DCAppAttestService`. App Attest only works on real hardware, so the
/// protocol lets tests and the Simulator run without it (docs/05-architecture.md §16).
///
/// This is anti-abuse protection, NOT user authentication (RULES.md §3). The private key lives in
/// the Secure Enclave and never leaves the device; only the key id, attestation, and per-request
/// assertion are sent to the relay.
protocol AppAttestKeyProviding: Sendable {
    /// False on Simulator and unsupported hardware.
    var isSupported: Bool { get }
    /// Creates a new Secure Enclave key and returns its id.
    func generateKey() async throws -> String
    /// Attests a freshly generated key against a server challenge.
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
    /// Signs a per-request challenge with an already attested key.
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

/// Stores the attested key id across launches. The key id is a public identifier, not a secret —
/// the private key it names is held by the Secure Enclave.
protocol AppAttestKeyIDStorage: Sendable {
    func loadKeyID() -> String?
    func saveKeyID(_ keyID: String?)
}

struct DeviceCheckAppAttestKeys: AppAttestKeyProviding {
    var isSupported: Bool { DCAppAttestService.shared.isSupported }

    func generateKey() async throws -> String {
        try await DCAppAttestService.shared.generateKey()
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: clientDataHash)
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: clientDataHash)
    }
}

struct UserDefaultsAppAttestKeyIDStorage: AppAttestKeyIDStorage {
    static let defaultsKey = "appAttestKeyID"

    func loadKeyID() -> String? {
        UserDefaults.standard.string(forKey: Self.defaultsKey)
    }

    func saveKeyID(_ keyID: String?) {
        UserDefaults.standard.set(keyID, forKey: Self.defaultsKey)
    }
}
