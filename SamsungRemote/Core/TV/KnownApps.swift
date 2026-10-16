import Foundation

/// Apps com ícone bundlado no app. Lista fechada por ora — adicionar um app novo é bundlar um
/// ícone e acrescentar uma entrada aqui. Ver `docs/specs/0002-atalhos-de-apps.md`.
///
/// `candidateAppIds`: valores de referência de duas bases comunitárias
/// (`xchwarze/samsung-tv-ws-api`, `blog-razrabotchika/homebridge-samsung-tizen-applications`),
/// em ordem de prioridade (mais recente/mais testado primeiro). Cada um é testado via `GET`
/// REST contra a TV (200 = existe, 404 = não); o primeiro que responder 200 vira o `appId`
/// real usado no `POST` de lançamento — nunca um valor fixo sem confirmação. Testar é sem
/// efeito colateral, então candidatos extras custam só alguns ms numa falha, nada num acerto.
struct KnownApp: Identifiable, Equatable, Sendable {
    let key: String
    let displayName: String
    let assetName: String
    let candidateAppIds: [String]

    var id: String { key }

    static let all: [KnownApp] = [
        KnownApp(
            key: "netflix", displayName: "Netflix", assetName: "AppNetflix",
            candidateAppIds: ["3201907018807", "11101200001", "org.tizen.netflixapp"]
        ),
        KnownApp(
            key: "youtube", displayName: "YouTube", assetName: "AppYouTube",
            candidateAppIds: ["111299001912", "9Ur5IzDKqV.TizenYouTube"]
        ),
        KnownApp(
            key: "prime-video", displayName: "Prime Video", assetName: "AppPrimeVideo",
            candidateAppIds: ["3201910019365", "3201512006785", "org.tizen.primevideo", "org.tizen.ignition"]
        ),
        KnownApp(
            key: "globoplay", displayName: "globoplay", assetName: "AppGloboplay",
            // ⚠️ os dois candidatos conhecidos deram 404 na TV de teste — provável sinal de que
            // o app não está instalado nela ainda, não de ID errado (ver spec 0002).
            candidateAppIds: ["3201908019022", "org.tizen.globoplayapp"]
        ),
    ]
}

/// Um `KnownApp` já resolvido contra a TV: tem o `appId` real desta TV (o candidato que
/// respondeu 200), pronto para o `POST` de lançamento.
struct ResolvedApp: Identifiable, Equatable, Sendable {
    let app: KnownApp
    let appId: String

    var id: String { app.key }
}
