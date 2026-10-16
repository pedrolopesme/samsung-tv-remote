import Foundation

/// Endpoints da API local das TVs Samsung Tizen (2016+).
/// Referência: `docs/protocol/samsung-tizen-remote.md`.
enum TVEndpoint {
    /// Porta do WebSocket com TLS (certificado autoassinado). Obrigatória em modelos 2018+.
    static let secureWebSocketPort = 8002
    /// Porta HTTP da API REST de informações.
    static let restPort = 8001

    /// `wss://<host>:8002/api/v2/channels/samsung.remote.control?name=<base64>&token=<token>`
    static func remoteControlURL(host: String, clientName: String, token: String?) -> URL? {
        guard isValidHost(host) else { return nil }
        var components = URLComponents()
        components.scheme = "wss"
        components.host = host
        components.port = secureWebSocketPort
        components.path = "/api/v2/channels/samsung.remote.control"
        var items = [URLQueryItem(name: "name", value: Data(clientName.utf8).base64EncodedString())]
        if let token, !token.isEmpty {
            items.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = items
        return components.url
    }

    /// `http://<host>:8001/api/v2/` — informações do aparelho (modelo, MAC, estado de energia).
    static func infoURL(host: String) -> URL? {
        guard isValidHost(host) else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = restPort
        components.path = "/api/v2/"
        return components.url
    }

    /// `http://<host>:8001/api/v2/applications/<appId>` — `GET` consulta (200 instalado,
    /// 404 não), `POST` lança. Validado na AU8000 real (ver `docs/specs/0002-atalhos-de-apps.md`),
    /// ao contrário do canal `ed.*` do WebSocket, que essa geração de firmware não implementa.
    static func applicationURL(host: String, appId: String) -> URL? {
        guard isValidHost(host), !appId.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = restPort
        components.path = "/api/v2/applications/\(appId)"
        return components.url
    }

    static func isValidHost(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == host else { return false }
        let forbidden = CharacterSet(charactersIn: "/:?#@ ")
        return host.rangeOfCharacter(from: forbidden) == nil
    }
}

/// Mensagens enviadas pelo app à TV pelo WebSocket.
enum RemoteMessage {
    enum Action: String, Sendable {
        /// Pressiona e solta (um toque).
        case click = "Click"
        /// Mantém pressionada até um `release`.
        case press = "Press"
        case release = "Release"
    }

    struct Payload: Encodable {
        let method = "ms.remote.control"
        let params: Params
    }

    struct Params: Encodable {
        let cmd: String
        let dataOfCmd: String
        let option = "false"
        let typeOfRemote = "SendRemoteKey"

        enum CodingKeys: String, CodingKey {
            case cmd = "Cmd"
            case dataOfCmd = "DataOfCmd"
            case option = "Option"
            case typeOfRemote = "TypeOfRemote"
        }
    }

    static func key(_ key: RemoteKey, action: Action = .click) throws -> String {
        let payload = Payload(params: Params(cmd: action.rawValue, dataOfCmd: key.rawValue))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }
}

/// Eventos recebidos da TV no canal de controle.
struct ChannelEvent: Decodable, Equatable {
    static let connect = "ms.channel.connect"
    static let unauthorized = "ms.channel.unauthorized"
    static let timeOut = "ms.channel.timeOut"

    let event: String
    /// Presente em `ms.channel.connect` quando a TV usa autenticação por token.
    let token: String?

    private enum CodingKeys: String, CodingKey { case event, data }
    private enum DataKeys: String, CodingKey { case token }

    init(event: String, token: String?) {
        self.event = event
        self.token = token
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        event = try container.decode(String.self, forKey: .event)
        // `data` muda de formato conforme o evento (objeto, array, string); só nos interessa o token.
        if let data = try? container.nestedContainer(keyedBy: DataKeys.self, forKey: .data) {
            token = try? data.decode(String.self, forKey: .token)
        } else {
            token = nil
        }
    }

    static func parse(_ text: String) -> ChannelEvent? {
        try? JSONDecoder().decode(ChannelEvent.self, from: Data(text.utf8))
    }
}

/// Resposta de `GET http://<host>:8001/api/v2/`.
struct TVDeviceInfo: Decodable, Equatable, Sendable {
    let name: String?
    let device: Device

    struct Device: Decodable, Equatable, Sendable {
        let name: String?
        let modelName: String?
        let powerState: String?
        let wifiMac: String?
        let networkType: String?
        let tokenAuthSupport: String?

        enum CodingKeys: String, CodingKey {
            case name
            case modelName
            case powerState = "PowerState"
            case wifiMac
            case networkType
            case tokenAuthSupport = "TokenAuthSupport"
        }
    }

    /// Modelos antigos não informam `PowerState`; se a API respondeu, consideramos ligada.
    var isOn: Bool {
        guard let state = device.powerState?.lowercased() else { return true }
        return state == "on"
    }

    /// Nome amigável sem o prefixo "[TV] " que a Samsung coloca.
    var displayName: String? {
        let raw = device.name ?? name
        return raw?.replacingOccurrences(of: "[TV] ", with: "")
    }
}
