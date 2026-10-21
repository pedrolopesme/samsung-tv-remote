import SwiftUI

/// Overlay de envio de texto pra TV (`SendInputString`), cobrindo o controle inteiro — não é um
/// popover pequeno, é foco total no texto. Design: FigCraft, arquivo "SamsungRemote", página
/// "0004 — Teclado / envio de texto" (redesenhada após o teste na TV real: o botão saiu do rodapé
/// de atalhos de apps e virou um 4º botão circular na fileira Fonte/Menu/Informações — ver
/// `KeyboardToggleButton`). Protocolo em `docs/protocol/samsung-tizen-remote.md` §3, ✅ validado
/// na AU8000 real (campos nativos do Tizen; não funciona em apps de streaming de terceiros — ver
/// `docs/specs/0004-teclado-envio-texto.md`).
struct TextKeyboardOverlay: View {
    @Binding var isOpen: Bool
    @Environment(RemoteModel.self) var model
    @State private var text = ""
    @State private var outcome: Outcome?
    @FocusState private var isTextFieldFocused: Bool

    private enum Outcome: Equatable { case sent, failed }

    var body: some View {
        ZStack(alignment: .top) {
            scrim
            VStack(spacing: 0) {
                closeButtonRow
                content
            }
        }
        .onAppear { isTextFieldFocused = true }
    }

    /// Mesma posição do botão "Teclado" na fileira Fonte/Menu/Informações (`RemoteView`) — a
    /// fileira real fica coberta pelo scrim, então o overlay redesenha o botão aqui, já no estado
    /// "ativo", servindo de botão de fechar (junto com Esc).
    private var closeButtonRow: some View {
        HStack {
            Spacer()
            KeyboardToggleButton(isActive: true) { close() }
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }

    private var scrim: some View {
        LinearGradient(
            colors: [
                Color(red: 0.039, green: 0.043, blue: 0.051).opacity(0.95),
                Color(red: 0.027, green: 0.031, blue: 0.039).opacity(0.99),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var accent: Color { outcome == .failed ? Theme.error : Theme.accent }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(accent)
                Text("TECLADO DA TV")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(accent.opacity(0.78))
            }

            VStack(spacing: 12) {
                TextField("Comece a digitar…", text: $text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(outcome == .failed ? 0.72 : 0.95))
                    .focused($isTextFieldFocused)
                    .onChange(of: text) { outcome = nil }
                    .onSubmit { submit() }
                    .onExitCommand { close() }

                Capsule()
                    .fill(text.isEmpty && outcome == nil ? accent.opacity(0.54) : accent)
                    .frame(width: 120, height: 2)
                    .shadow(color: accent.opacity(0.4), radius: 8)

                Text(microHint)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.36))
            }
            .padding(.top, 24)

            if let outcome {
                statusPill(for: outcome)
                    .padding(.top, 20)
            }

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    keyCap("Enter", hint: outcome == .failed ? "tenta" : "envia")
                    keyCap("Esc", hint: "fecha")
                }
                Text(protocolNote)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.white.opacity(0.30))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var microHint: String {
        switch outcome {
        case .sent: "UTF-8 → Base64 · SendInputString"
        case .failed: "texto continua aqui · nada foi perdido"
        case nil: "vale nos campos nativos da TV (Smart Hub, busca)"
        }
    }

    private var protocolNote: String {
        outcome == .failed
            ? "overlay não trava: dá pra reenviar ou fechar"
            : "Esc fecha o teclado e envia SendInputEnd"
    }

    private func statusPill(for outcome: Outcome) -> some View {
        let isError = outcome == .failed
        let tint = isError ? Theme.error : Theme.success
        let label = isError ? "Falha ao enviar · TV desconectada" : "Enviado · pode digitar de novo"
        let labelColor = isError
            ? Color(red: 1.0, green: 0.639, blue: 0.608)
            : Color(red: 0.561, green: 0.909, blue: 0.698)

        return HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .shadow(color: tint.opacity(0.6), radius: 5)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(labelColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.30), lineWidth: 1))
    }

    private func keyCap(_ key: String, hint: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(.white.opacity(0.17), lineWidth: 1))
            Text(hint)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.54))
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            let sent = await model.sendText(trimmed)
            outcome = sent ? .sent : .failed
        }
    }

    private func close() {
        model.endTextInput()
        isOpen = false
    }
}

/// Botão circular "Teclado" — 4º botão da fileira Fonte/Menu/Informações no topo do `RemoteView`
/// (mesmo tamanho/posição/estilo dos `KeyButton` vizinhos), reaproveitado aqui dentro do overlay
/// (já "ativo") como botão de fechar. Não é um `KeyButton` porque não manda uma `RemoteKey` pra
/// TV — abre/fecha o overlay local, então tem ação customizada em vez de `model.send(key)`.
struct KeyboardToggleButton: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "keyboard")
        }
        .buttonStyle(KeyboardKeyCapStyle(isActive: isActive))
        .help(isActive ? "Fechar o teclado" : "Enviar texto pra TV")
        .accessibilityLabel(isActive ? "Fechar o teclado" : "Teclado")
    }
}

/// Variante de `KeyCapStyle` com um segundo estado "ativo" (overlay aberto): gradiente azul,
/// borda e glow de `Theme.accent` em vez do relevo neutro padrão. O estado inativo é visualmente
/// idêntico a `KeyCapStyle(tint: Theme.key, shape: .circle)` — mesma fórmula de gradiente/sombra.
private struct KeyboardKeyCapStyle: ButtonStyle {
    let isActive: Bool

    private static let activeTop = Color(red: 0.180, green: 0.290, blue: 0.447)
    private static let activeBottom = Color(red: 0.133, green: 0.188, blue: 0.290)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.label)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { background(pressed: configuration.isPressed) }
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        if isActive {
            Circle()
                .fill(LinearGradient(colors: [Self.activeTop, Self.activeBottom], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(Theme.accent, lineWidth: 1.5))
                .shadow(color: Theme.accent.opacity(0.35), radius: 8)
        } else {
            Circle()
                .fill(Theme.keyGradient(Theme.key, pressed: pressed))
                .overlay(Circle().stroke(Color.white.opacity(pressed ? 0.04 : 0.13), lineWidth: 1))
                .shadow(color: .black.opacity(pressed ? 0.25 : 0.5), radius: pressed ? 1 : 4, y: pressed ? 1 : 3)
        }
    }
}
