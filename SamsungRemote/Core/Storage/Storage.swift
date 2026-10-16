import Foundation
import Security

/// Configuração da TV pareada. Fica em `UserDefaults` (container do sandbox), nunca no repositório.
struct TVConfiguration: Codable, Equatable, Sendable {
    var host: String
    var macAddress: String?
    var name: String?
    var modelName: String?

    var displayName: String { name ?? modelName ?? host }
}

struct ConfigurationStore {
    private let defaults: UserDefaults
    private let key = "tv.configuration.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TVConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TVConfiguration.self, from: data)
    }

    func save(_ configuration: TVConfiguration?) {
        guard let configuration, let data = try? JSONEncoder().encode(configuration) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}

/// Favoritos de atalhos de apps, por chave (`KnownApp.key`), ordenados pela ordem de marcação.
/// Ver `docs/specs/0002-atalhos-de-apps.md`.
struct AppFavoritesStore {
    private let defaults: UserDefaults
    private let key = "tv.apps.favorites.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func save(_ keys: [String]) {
        defaults.set(keys, forKey: key)
    }
}

/// Onde guardamos o token de pareamento devolvido pela TV.
protocol TokenStore {
    func token(for tvID: String) -> String?
    func setToken(_ token: String?, for tvID: String)
}

/// Implementação padrão: item genérico no Keychain, uma entrada por TV (chave = host).
struct KeychainTokenStore: TokenStore {
    var service = "com.pedrolopesme.SamsungRemote.pairing-token"

    func token(for tvID: String) -> String? {
        var query = baseQuery(for: tvID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setToken(_ token: String?, for tvID: String) {
        let query = baseQuery(for: tvID)
        SecItemDelete(query as CFDictionary)
        guard let token, !token.isEmpty else { return }

        var attributes = query
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func baseQuery(for tvID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tvID,
        ]
    }
}

/// Usado em testes e previews.
final class InMemoryTokenStore: TokenStore {
    private var tokens: [String: String] = [:]
    func token(for tvID: String) -> String? { tokens[tvID] }
    func setToken(_ token: String?, for tvID: String) { tokens[tvID] = token }
}
