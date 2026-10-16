import Foundation
import Testing
@testable import SamsungRemote

@Suite("Atalhos de apps (spec 0002)")
struct AppShortcutsTests {
    @Test("ed.installedApp.get gera o payload ms.channel.emit esperado")
    func installedAppsRequestPayload() throws {
        let json = try RemoteMessage.installedAppsRequest()
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["method"] as? String == "ms.channel.emit")

        let params = try #require(object["params"] as? [String: Any])
        #expect(params["event"] as? String == "ed.installedApp.get")
        #expect(params["to"] as? String == "host")
        #expect(params["data"] == nil)
    }

    @Test("ed.apps.launch gera appId, action_type e metaTag")
    func launchAppPayload() throws {
        let json = try RemoteMessage.launchApp(appId: "3201907018807")
        let object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let params = try #require(object["params"] as? [String: Any])
        #expect(params["event"] as? String == "ed.apps.launch")

        let data = try #require(params["data"] as? [String: String])
        #expect(data == [
            "appId": "3201907018807",
            "action_type": "DEEP_LINK",
            "metaTag": "",
        ])
    }

    @Test("Resposta de ed.installedApp.get: entradas válidas, desconhecidas e malformadas")
    func parsesInstalledAppsTolerantly() throws {
        // Formato confirmado em samsungtvws/event.py e ha-samsungtv-tizen/media_player.py
        // (ver docs/specs/0002-atalhos-de-apps.md) — ainda não capturado na AU8000 real.
        let text = #"""
        {"event":"ed.installedApp.get","data":{"data":[
            {"appId":"3201907018807","name":"Netflix"},
            {"appId":"111299001912","name":"YouTube","extraField":"ignorado"},
            {"name":"Sem appId"},
            {"appId":"semNome"},
            {"appId":"3201908019022","name":"globoplay"}
        ]}}
        """#
        let event = try #require(InstalledAppsEvent.parse(text))
        #expect(event.apps == [
            InstalledApp(appId: "3201907018807", name: "Netflix"),
            InstalledApp(appId: "111299001912", name: "YouTube"),
            InstalledApp(appId: "3201908019022", name: "globoplay"),
        ])
    }

    @Test("Evento com nome diferente de ed.installedApp.get não decodifica")
    func rejectsOtherEvents() {
        let text = #"{"event":"ms.channel.connect","data":{"data":[]}}"#
        #expect(InstalledAppsEvent.parse(text) == nil)
    }

    @Test(
        "Match de nome tolera variação de case e espaço",
        arguments: [
            ("Netflix", "netflix"), (" netflix ", "netflix"), ("NETFLIX", "netflix"),
            ("Prime Video", "prime-video"), ("prime video", "prime-video"), ("PRIME VIDEO", "prime-video"),
            ("globoplay", "globoplay"), ("GloboPlay", "globoplay"),
            ("YouTube", "youtube"),
        ]
    )
    func matchesKnownAppByNormalizedName(reportedName: String, expectedKey: String) throws {
        let known = try #require(KnownApp.all.first { $0.matchName == KnownApp.normalize(reportedName) })
        #expect(known.key == expectedKey)
    }

    @Test("Nome não reconhecido não casa com nenhum app conhecido")
    func unknownNameMatchesNothing() {
        #expect(KnownApp.all.first { $0.matchName == KnownApp.normalize("Disney+") } == nil)
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
