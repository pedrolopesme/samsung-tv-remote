import Foundation
import Testing
@testable import SamsungRemote

@Suite("Protocolo Samsung Tizen")
struct ProtocolTests {
    @Test("Click gera o payload ms.remote.control esperado")
    func clickPayload() throws {
        let json = try RemoteMessage.key(.volumeUp)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["method"] as? String == "ms.remote.control")

        let params = try #require(object["params"] as? [String: String])
        #expect(params == [
            "Cmd": "Click",
            "DataOfCmd": "KEY_VOLUP",
            "Option": "false",
            "TypeOfRemote": "SendRemoteKey",
        ])
    }

    @Test("Press/Release usam o Cmd correto")
    func pressRelease() throws {
        #expect(try RemoteMessage.key(.up, action: .press).contains("\"Cmd\":\"Press\""))
        #expect(try RemoteMessage.key(.up, action: .release).contains("\"Cmd\":\"Release\""))
    }

    @Test("URL do WebSocket usa wss:8002, nome em base64 e token")
    func remoteControlURL() throws {
        let url = try #require(TVEndpoint.remoteControlURL(host: "192.168.0.50", clientName: "Mac Remote", token: "12345"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "wss")
        #expect(components.port == 8002)
        #expect(components.path == "/api/v2/channels/samsung.remote.control")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(items["name"] == Data("Mac Remote".utf8).base64EncodedString())
        #expect(items["token"] == "12345")
    }

    @Test("Sem token, a URL não leva o parâmetro token")
    func remoteControlURLWithoutToken() throws {
        let url = try #require(TVEndpoint.remoteControlURL(host: "10.0.0.2", clientName: "x", token: nil))
        #expect(!url.absoluteString.contains("token="))
    }

    @Test("Hosts inválidos são rejeitados", arguments: ["", " 192.168.0.1", "http://tv", "tv/path", "a b"])
    func invalidHosts(host: String) {
        #expect(TVEndpoint.remoteControlURL(host: host, clientName: "x", token: nil) == nil)
        #expect(TVEndpoint.infoURL(host: host) == nil)
    }

    @Test("ms.channel.connect com token")
    func parseConnectEvent() {
        let text = #"{"event":"ms.channel.connect","data":{"clients":[],"id":"abc","token":"98765"}}"#
        #expect(ChannelEvent.parse(text) == ChannelEvent(event: ChannelEvent.connect, token: "98765"))
    }

    @Test("ms.channel.unauthorized sem data")
    func parseUnauthorizedEvent() {
        let text = #"{"event":"ms.channel.unauthorized"}"#
        #expect(ChannelEvent.parse(text) == ChannelEvent(event: ChannelEvent.unauthorized, token: nil))
    }

    @Test("Eventos com data em outro formato não quebram o parser")
    func parseEventWithArrayData() {
        let text = #"{"event":"ed.installedApp.get","data":[{"appId":"111299001912"}]}"#
        #expect(ChannelEvent.parse(text)?.token == nil)
    }

    @Test("Decodifica /api/v2/ de uma TV 2021")
    func decodeDeviceInfo() throws {
        let info = try JSONDecoder().decode(TVDeviceInfo.self, from: Data(Fixtures.au8000Info.utf8))
        #expect(info.device.modelName == "UN65AU8000GXZD")
        #expect(info.displayName == "Samsung AU8000 65")
        #expect(info.isOn)
        #expect(info.device.tokenAuthSupport == "true")
    }

    @Test("PowerState standby => desligada")
    func standbyIsOff() throws {
        let json = Fixtures.au8000Info.replacingOccurrences(of: "\"PowerState\": \"on\"", with: "\"PowerState\": \"standby\"")
        let info = try JSONDecoder().decode(TVDeviceInfo.self, from: Data(json.utf8))
        #expect(!info.isOn)
    }
}

enum Fixtures {
    /// Formato representativo de `GET http://<tv>:8001/api/v2/` em modelos Tizen 2021.
    /// Valores fictícios (MAC, id) — não colocar dados reais da TV no repositório.
    static let au8000Info = """
    {
      "device": {
        "FrameTVSupport": "false",
        "GamePadSupport": "true",
        "ImeSyncedSupport": "true",
        "Language": "pt_BR",
        "OS": "Tizen",
        "PowerState": "on",
        "TokenAuthSupport": "true",
        "VoiceSupport": "true",
        "WallScreenRatio": "0",
        "WallService": "false",
        "countryCode": "BR",
        "description": "Samsung DTV RCR",
        "developerIP": "0.0.0.0",
        "developerMode": "0",
        "duid": "uuid:00000000-0000-0000-0000-000000000000",
        "firmwareVersion": "Unknown",
        "id": "uuid:00000000-0000-0000-0000-000000000000",
        "ip": "192.168.0.50",
        "model": "21_NIKEL_UHD",
        "modelName": "UN65AU8000GXZD",
        "name": "[TV] Samsung AU8000 65",
        "networkType": "wired",
        "resolution": "3840x2160",
        "smartHubAgreement": "true",
        "type": "Samsung SmartTV",
        "udn": "uuid:00000000-0000-0000-0000-000000000000",
        "wifiMac": "00:11:22:33:44:55"
      },
      "id": "uuid:00000000-0000-0000-0000-000000000000",
      "isSupport": "{}",
      "name": "[TV] Samsung AU8000 65",
      "remote": "1.0",
      "type": "Samsung SmartTV",
      "uri": "http://192.168.0.50:8001/api/v2/",
      "version": "2.0.25"
    }
    """
}
