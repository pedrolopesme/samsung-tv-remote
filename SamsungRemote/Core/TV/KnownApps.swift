import Foundation

/// Apps com ícone bundlado no app. Lista fechada por ora — adicionar um app novo é bundlar um
/// ícone e acrescentar uma entrada aqui. Ver `docs/specs/0002-atalhos-de-apps.md`.
///
/// O `appId` real **nunca** vem daqui: é sempre resolvido a partir da resposta de
/// `ed.installedApp.get`, casando `matchName` (normalizado) com o `name` que a TV reportar.
struct KnownApp: Identifiable, Equatable, Sendable {
    let key: String
    let displayName: String
    let matchName: String
    let assetName: String

    var id: String { key }

    static let all: [KnownApp] = [
        KnownApp(key: "netflix", displayName: "Netflix", matchName: "netflix", assetName: "AppNetflix"),
        KnownApp(key: "youtube", displayName: "YouTube", matchName: "youtube", assetName: "AppYouTube"),
        KnownApp(key: "prime-video", displayName: "Prime Video", matchName: "prime video", assetName: "AppPrimeVideo"),
        KnownApp(key: "globoplay", displayName: "globoplay", matchName: "globoplay", assetName: "AppGloboplay"),
    ]

    /// Normaliza um nome reportado pela TV (lowercase + trim) para comparar com `matchName`.
    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Um `KnownApp` já resolvido contra a última resposta de `ed.installedApp.get`: tem o `appId`
/// real desta TV, pronto para `ed.apps.launch`.
struct ResolvedApp: Identifiable, Equatable, Sendable {
    let app: KnownApp
    let appId: String

    var id: String { app.key }
}
