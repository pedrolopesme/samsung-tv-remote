import AppKit
import SwiftUI

/// Tela principal: o controle remoto.
struct RemoteView: View {
    @Environment(RemoteModel.self) var model
    @FocusState var isFocused: Bool

    var body: some View {
        VStack(spacing: 18) {
            HeaderView()
            AppShortcutsRow()

            HStack(spacing: 14) {
                KeyButton(.source, systemImage: "rectangle.on.rectangle")
                KeyButton(.menu, systemImage: "line.3.horizontal")
                KeyButton(.info, systemImage: "info")
            }
            .frame(height: 40)
            .padding(.horizontal, 30)

            DPad()

            HStack(spacing: 14) {
                KeyButton(.back, systemImage: "arrow.uturn.backward", shape: .capsule)
                KeyButton(.home, systemImage: "house.fill", shape: .capsule)
                KeyButton(.exit, systemImage: "xmark", shape: .capsule)
            }
            .frame(height: 40)

            HStack(alignment: .center) {
                Rocker(up: .volumeUp, down: .volumeDown, upSymbol: "plus", downSymbol: "minus", caption: "VOL")
                Spacer()
                VStack(spacing: 12) {
                    KeyButton(.mute, systemImage: "speaker.slash.fill")
                        .frame(width: 50, height: 50)
                    KeyButton(.guide, systemImage: "list.bullet.rectangle")
                        .frame(width: 50, height: 50)
                }
                Spacer()
                Rocker(up: .channelUp, down: .channelDown, upSymbol: "chevron.up", downSymbol: "chevron.down", caption: "CH")
            }
            .padding(.horizontal, 12)

            HStack(spacing: 10) {
                KeyButton(.rewind, systemImage: "backward.fill", shape: .rounded)
                KeyButton(.play, systemImage: "play.fill", shape: .rounded)
                KeyButton(.pause, systemImage: "pause.fill", shape: .rounded)
                KeyButton(.fastForward, systemImage: "forward.fill", shape: .rounded)
            }
            .frame(height: 36)

            FooterView()
        }
        .padding(20)
        .frame(width: Theme.remoteWidth)
        .background(Theme.bodyGradient)
        .overlay(alignment: .top) {
            if model.status == .awaitingApproval {
                ApprovalBanner()
                    .padding(12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.status)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress { press in
            guard let key = KeyboardShortcuts.remoteKey(for: press) else { return .ignored }
            model.send(key)
            return .handled
        }
        .onAppear {
            isFocused = true
            Task { await model.connect() }
        }
    }
}

/// Nome da TV, status e botão de energia.
private struct HeaderView: View {
    @Environment(RemoteModel.self) var model

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.configuration?.displayName ?? "Samsung TV")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.label)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.status.color)
                        .frame(width: 7, height: 7)
                        .shadow(color: model.status.color.opacity(0.8), radius: 3)
                    Text(model.status.title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
            Spacer(minLength: 0)
            Button {
                Haptics.tap()
                model.togglePower()
            } label: {
                if model.status == .waking {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "power").font(.system(size: 16, weight: .heavy))
                }
            }
            .buttonStyle(KeyCapStyle(tint: Theme.power, shape: .circle))
            .frame(width: 44, height: 44)
            .help(model.status == .connected ? "Desligar a TV" : "Ligar a TV (Wake-on-LAN)")
        }
    }
}

/// Mensagem de erro + atalhos de rodapé.
private struct FooterView: View {
    @Environment(RemoteModel.self) var model

    var body: some View {
        VStack(spacing: 10) {
            if let message = model.errorMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warning)
                    Text(message)
                        .foregroundStyle(Theme.label)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
            }

            HStack {
                SettingsLink {
                    Image(systemName: "gearshape.fill")
                }
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
                .help("Preferências")

                Spacer()

                if model.status != .connected && !model.isBusy {
                    Button("Reconectar") { Task { await model.connect() } }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power.circle")
                }
                .help("Sair do Samsung Remote")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryLabel)
            .font(.system(size: 13))
        }
    }
}

private struct ApprovalBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tv.badge.wifi")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Aceite na TV")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("Use o controle físico para permitir \"\(RemoteModel.clientName)\".")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.label)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.accent.opacity(0.4)))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }
}

/// Mapa de teclado → teclas da TV. Documentado em `docs/specs/0001-remote-control-mvp.md`.
enum KeyboardShortcuts {
    static func remoteKey(for press: KeyPress) -> RemoteKey? {
        switch press.key {
        case .upArrow: return .up
        case .downArrow: return .down
        case .leftArrow: return .left
        case .rightArrow: return .right
        case .return: return .enter
        case .delete: return .back
        case .space: return .play
        default: break
        }
        switch press.characters.lowercased() {
        case "+", "=": return .volumeUp
        case "-", "_": return .volumeDown
        case "m": return .mute
        case "h": return .home
        case "p": return .pause
        case "[": return .channelDown
        case "]": return .channelUp
        case "0": return .digit0
        case "1": return .digit1
        case "2": return .digit2
        case "3": return .digit3
        case "4": return .digit4
        case "5": return .digit5
        case "6": return .digit6
        case "7": return .digit7
        case "8": return .digit8
        case "9": return .digit9
        default: return nil
        }
    }
}

/// Linha de atalhos de apps favoritos, entre o cabeçalho e o D-pad. Some se não houver
/// favorito reconhecido na TV conectada. Ver `docs/specs/0002-atalhos-de-apps.md` (FR-4/FR-6).
private struct AppShortcutsRow: View {
    @Environment(RemoteModel.self) var model

    var body: some View {
        if !model.favoriteApps.isEmpty {
            HStack(spacing: 14) {
                ForEach(model.favoriteApps) { resolved in
                    AppShortcutButton(resolved: resolved)
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 30)
        }
    }
}

/// Toque abre o app na TV (`ed.apps.launch`). Mesmo estilo de `KeyButton`, com o logo do app
/// no lugar do SF Symbol.
private struct AppShortcutButton: View {
    let resolved: ResolvedApp
    @Environment(RemoteModel.self) var model

    var body: some View {
        Button {
            Haptics.tap()
            model.launchApp(resolved)
        } label: {
            Image(resolved.app.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(Circle())
        }
        .buttonStyle(KeyCapStyle(tint: Theme.key, shape: .circle))
        .help(resolved.app.displayName)
        .accessibilityLabel(resolved.app.displayName)
    }
}
