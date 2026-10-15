import Foundation

/// Teclas aceitas pelo canal `samsung.remote.control` da TV.
///
/// O `rawValue` é exatamente o valor enviado em `DataOfCmd`.
/// Referência: `docs/protocol/samsung-tizen-remote.md` (seção "Teclas").
enum RemoteKey: String, CaseIterable, Sendable {
    // Energia e navegação de sistema
    case power = "KEY_POWER"
    case home = "KEY_HOME"
    case back = "KEY_RETURN"
    case exit = "KEY_EXIT"
    case menu = "KEY_MENU"
    case source = "KEY_SOURCE"
    case info = "KEY_INFO"
    case guide = "KEY_GUIDE"

    // D-pad
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case enter = "KEY_ENTER"

    // Áudio
    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case mute = "KEY_MUTE"

    // Canais
    case channelUp = "KEY_CHUP"
    case channelDown = "KEY_CHDOWN"
    case previousChannel = "KEY_PRECH"

    // Mídia
    case play = "KEY_PLAY"
    case pause = "KEY_PAUSE"
    case stop = "KEY_STOP"
    case rewind = "KEY_REWIND"
    case fastForward = "KEY_FF"

    // Numéricas
    case digit0 = "KEY_0"
    case digit1 = "KEY_1"
    case digit2 = "KEY_2"
    case digit3 = "KEY_3"
    case digit4 = "KEY_4"
    case digit5 = "KEY_5"
    case digit6 = "KEY_6"
    case digit7 = "KEY_7"
    case digit8 = "KEY_8"
    case digit9 = "KEY_9"

    /// Texto curto usado em tooltips e acessibilidade.
    var title: String {
        switch self {
        case .power: "Liga/desliga"
        case .home: "Início"
        case .back: "Voltar"
        case .exit: "Sair"
        case .menu: "Menu"
        case .source: "Fonte"
        case .info: "Informações"
        case .guide: "Guia"
        case .up: "Cima"
        case .down: "Baixo"
        case .left: "Esquerda"
        case .right: "Direita"
        case .enter: "OK"
        case .volumeUp: "Aumentar volume"
        case .volumeDown: "Diminuir volume"
        case .mute: "Mudo"
        case .channelUp: "Próximo canal"
        case .channelDown: "Canal anterior"
        case .previousChannel: "Último canal"
        case .play: "Reproduzir"
        case .pause: "Pausar"
        case .stop: "Parar"
        case .rewind: "Retroceder"
        case .fastForward: "Avançar"
        default: rawValue.replacingOccurrences(of: "KEY_", with: "")
        }
    }
}
