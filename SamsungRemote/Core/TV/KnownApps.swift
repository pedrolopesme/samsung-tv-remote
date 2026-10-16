import Foundation

/// Apps com ícone bundlado no app. Lista fechada por ora — adicionar um app novo é bundlar um
/// ícone e acrescentar uma entrada aqui. Ver `docs/specs/0002-atalhos-de-apps.md`.
///
/// `candidateAppIds`: valores de referência da comunidade (`xchwarze/samsung-tv-ws-api`), em
/// ordem de prioridade (mais recente primeiro). Cada um é testado via `GET` REST contra a TV
/// (200 = existe, 404 = não); o primeiro que responder 200 vira o `appId` real usado no
/// `POST` de lançamento — nunca um valor fixo sem confirmação.
struct KnownApp: Identifiable, Equatable, Sendable {
    let key: String
    let displayName: String
    let assetName: String
    let candidateAppIds: [String]

    var id: String { key }

    static let all: [KnownApp] = [
        KnownApp(key: "netflix", displayName: "Netflix", assetName: "AppNetflix", candidateAppIds: ["3201907018807", "11101200001"]),
        KnownApp(key: "youtube", displayName: "YouTube", assetName: "AppYouTube", candidateAppIds: ["111299001912"]),
        KnownApp(key: "prime-video", displayName: "Prime Video", assetName: "AppPrimeVideo", candidateAppIds: ["3201910019365", "3201512006785"]),
        KnownApp(key: "globoplay", displayName: "globoplay", assetName: "AppGloboplay", candidateAppIds: ["3201908019022"]),
    ]
}

/// Um `KnownApp` já resolvido contra a TV: tem o `appId` real desta TV (o candidato que
/// respondeu 200), pronto para o `POST` de lançamento.
struct ResolvedApp: Identifiable, Equatable, Sendable {
    let app: KnownApp
    let appId: String

    var id: String { app.key }
}
