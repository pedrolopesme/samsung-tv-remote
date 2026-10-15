import AppKit
import SwiftUI

/// Tokens visuais do controle. O app usa sempre o esquema escuro:
/// o controle imita um objeto físico (corpo grafite, teclas com relevo).
enum Theme {
    // Corpo do controle
    static let bodyTop = Color(red: 0.17, green: 0.18, blue: 0.20)
    static let bodyBottom = Color(red: 0.07, green: 0.075, blue: 0.09)
    static let bodyEdge = Color.white.opacity(0.08)

    // Teclas
    static let key = Color(red: 0.23, green: 0.24, blue: 0.27)
    static let keyRing = Color(red: 0.13, green: 0.14, blue: 0.16)
    static let label = Color.white.opacity(0.9)
    static let secondaryLabel = Color.white.opacity(0.48)

    // Acentos
    static let accent = Color(red: 0.38, green: 0.66, blue: 1.0)
    static let ok = Color(red: 0.24, green: 0.45, blue: 0.95)
    static let power = Color(red: 0.93, green: 0.30, blue: 0.28)
    static let success = Color(red: 0.35, green: 0.85, blue: 0.55)
    static let warning = Color(red: 1.0, green: 0.74, blue: 0.30)

    static let remoteWidth: CGFloat = 288

    static var bodyGradient: LinearGradient {
        LinearGradient(colors: [bodyTop, bodyBottom], startPoint: .top, endPoint: .bottom)
    }

    static func keyGradient(_ tint: Color, pressed: Bool) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(pressed ? 0.78 : 1.0), tint.opacity(pressed ? 0.62 : 0.78)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum Haptics {
    /// Feedback leve no trackpad Force Touch a cada tecla.
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

extension RemoteModel.Status {
    var title: String {
        switch self {
        case .notConfigured: "Sem TV"
        case .disconnected: "Desconectado"
        case .connecting: "Conectando…"
        case .awaitingApproval: "Aceite na TV"
        case .connected: "Conectado"
        case .waking: "Ligando…"
        }
    }

    var color: Color {
        switch self {
        case .connected: Theme.success
        case .connecting, .awaitingApproval, .waking: Theme.warning
        case .disconnected, .notConfigured: Theme.secondaryLabel
        }
    }
}
