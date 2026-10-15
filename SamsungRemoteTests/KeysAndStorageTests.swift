import Foundation
import Testing
@testable import SamsungRemote

@Suite("Teclas e armazenamento")
struct KeysAndStorageTests {
    @Test("Toda RemoteKey usa o prefixo KEY_")
    func allKeysHavePrefix() {
        for key in RemoteKey.allCases {
            #expect(key.rawValue.hasPrefix("KEY_"), "\(key) = \(key.rawValue)")
        }
    }

    @Test("Teclas principais batem com o protocolo")
    func coreKeyCodes() {
        #expect(RemoteKey.back.rawValue == "KEY_RETURN")
        #expect(RemoteKey.enter.rawValue == "KEY_ENTER")
        #expect(RemoteKey.fastForward.rawValue == "KEY_FF")
    }

    @Test("ConfigurationStore salva, carrega e apaga")
    func configurationRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "tests.\(UUID().uuidString)"))
        let store = ConfigurationStore(defaults: defaults)
        #expect(store.load() == nil)

        let configuration = TVConfiguration(host: "192.168.0.50", macAddress: "00:11:22:33:44:55", name: "Sala", modelName: "UN65AU8000GXZD")
        store.save(configuration)
        #expect(store.load() == configuration)

        store.save(nil)
        #expect(store.load() == nil)
    }

    @Test("InMemoryTokenStore guarda por TV")
    func tokenStore() {
        let tokens = InMemoryTokenStore()
        tokens.setToken("a", for: "tv1")
        tokens.setToken("b", for: "tv2")
        #expect(tokens.token(for: "tv1") == "a")
        tokens.setToken(nil, for: "tv1")
        #expect(tokens.token(for: "tv1") == nil)
        #expect(tokens.token(for: "tv2") == "b")
    }
}
