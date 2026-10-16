import Foundation
import Testing
@testable import SamsungRemote

@Suite("Atalhos de apps (spec 0002)")
struct AppShortcutsTests {
    @Test("URL de aplicativo usa REST :8001/api/v2/applications/<appId>")
    func applicationURL() throws {
        let url = try #require(TVEndpoint.applicationURL(host: "192.168.0.50", appId: "3201907018807"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "http")
        #expect(components.port == 8001)
        #expect(components.path == "/api/v2/applications/3201907018807")
    }

    @Test("Host inválido ou appId vazio não gera URL")
    func applicationURLRejectsInvalidInput() {
        #expect(TVEndpoint.applicationURL(host: "tv/path", appId: "123") == nil)
        #expect(TVEndpoint.applicationURL(host: "192.168.0.50", appId: "") == nil)
    }

    @Test("Todo KnownApp tem pelo menos um appId candidato")
    func knownAppsHaveCandidates() {
        for app in KnownApp.all {
            #expect(!app.candidateAppIds.isEmpty, "\(app.key) sem candidateAppIds")
        }
    }

    @Test("AppFavoritesStore salva, carrega e apaga")
    func favoritesRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "tests.\(UUID().uuidString)"))
        let store = AppFavoritesStore(defaults: defaults)
        #expect(store.load() == [])

        store.save(["netflix", "youtube"])
        #expect(store.load() == ["netflix", "youtube"])

        store.save([])
        #expect(store.load() == [])
    }
}
