import Foundation

/// Cliente da API REST (porta 8001). Usado para validar o IP, descobrir modelo/MAC
/// e checar se a TV está ligada antes de abrir o WebSocket.
enum TVInfoClient {
    static func fetch(host: String, timeout: TimeInterval = 2) async throws -> TVDeviceInfo {
        guard let url = TVEndpoint.infoURL(host: host) else {
            throw TVConnectionError.invalidHost
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(TVDeviceInfo.self, from: data)
        } catch is DecodingError {
            throw TVConnectionError.notASamsungTV
        } catch {
            throw TVConnectionError.unreachable
        }
    }
}
