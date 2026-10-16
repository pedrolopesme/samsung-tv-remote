import Foundation

/// Consulta e lança apps instalados via `GET`/`POST http://<host>:8001/api/v2/applications/<appId>`.
///
/// O canal WebSocket (`ed.installedApp.get`/`ed.apps.launch`, ambos `ms.channel.emit`) **não
/// existe** em TVs Tizen 2021+: `ed.installedApp.get` é aceito e ignorado em silêncio (nenhum
/// handler escuta esse evento), e tentativas de método de topo (`ms.application.get`) retornam
/// `{"event":"ms.error","data":{"message":"unrecognized method value"}}`. Confirmado na AU8000
/// real. A REST, ao contrário do que `docs/protocol/samsung-tizen-remote.md` supunha (⚠️ "alguns
/// firmwares 2021+ retornam 404"), funciona nela. Ver `docs/specs/0002-atalhos-de-apps.md`.
enum TVApplicationClient {
    /// `GET` — `true` se a TV conhece esse `appId` (200), `false` se não (404 ou qualquer falha
    /// de rede). Nunca lança: ausência de app é um resultado esperado, não um erro.
    static func isAvailable(host: String, appId: String, timeout: TimeInterval = 2) async -> Bool {
        guard let url = TVEndpoint.applicationURL(host: host, appId: appId) else { return false }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse
        else { return false }
        return http.statusCode == 200
    }

    /// `POST` — lança o app. Fire-and-forget: a TV não garante confirmação útil além do status
    /// HTTP, e falhas de rede não devem travar o controle (FR-6 da spec 0002).
    static func launch(host: String, appId: String, timeout: TimeInterval = 2) async {
        guard let url = TVEndpoint.applicationURL(host: host, appId: appId) else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
    }
}
