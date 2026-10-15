import SwiftUI

/// Estilo de tecla com relevo: gradiente, borda de luz e sombra que "afunda" ao pressionar.
struct KeyCapStyle: ButtonStyle {
    enum KeyShape { case circle, capsule, rounded }

    var tint: Color = Theme.key
    var shape: KeyShape = .circle

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.label)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { background(pressed: configuration.isPressed) }
            .contentShape(anyShape)
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: configuration.isPressed)
    }

    private var anyShape: AnyShape {
        switch shape {
        case .circle: AnyShape(Circle())
        case .capsule: AnyShape(Capsule())
        case .rounded: AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func background(pressed: Bool) -> some View {
        anyShape
            .fill(Theme.keyGradient(tint, pressed: pressed))
            .overlay(anyShape.stroke(Color.white.opacity(pressed ? 0.04 : 0.13), lineWidth: 1))
            .shadow(color: .black.opacity(pressed ? 0.25 : 0.5), radius: pressed ? 1 : 4, y: pressed ? 1 : 3)
    }
}

/// Botão que envia uma tecla para a TV com um toque.
struct KeyButton<Label: View>: View {
    let key: RemoteKey
    var shape: KeyCapStyle.KeyShape = .circle
    var tint: Color = Theme.key
    @ViewBuilder let label: () -> Label

    @Environment(RemoteModel.self) var model

    var body: some View {
        Button {
            Haptics.tap()
            model.send(key)
        } label: {
            label()
        }
        .buttonStyle(KeyCapStyle(tint: tint, shape: shape))
        .help(key.title)
        .accessibilityLabel(key.title)
    }
}

extension KeyButton where Label == Image {
    init(_ key: RemoteKey, systemImage: String, shape: KeyCapStyle.KeyShape = .circle, tint: Color = Theme.key) {
        self.init(key: key, shape: shape, tint: tint) { Image(systemName: systemImage) }
    }
}

/// Tecla que repete enquanto está pressionada (volume e canal).
/// Primeiro envio imediato, depois de 450 ms repete a cada 140 ms.
struct RepeatKeyButton<Label: View>: View {
    let key: RemoteKey
    @ViewBuilder let label: () -> Label

    @Environment(RemoteModel.self) var model
    @State var isPressed = false
    @State var repeatTask: Task<Void, Never>? = nil

    var body: some View {
        label()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .foregroundStyle(isPressed ? Theme.accent : Theme.label)
            .scaleEffect(isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isPressed { begin() } }
                    .onEnded { _ in end() }
            )
            .help(key.title)
            .accessibilityElement()
            .accessibilityLabel(key.title)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.send(key) }
            .onDisappear { end() }
    }

    private func begin() {
        isPressed = true
        Haptics.tap()
        model.send(key)
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            while !Task.isCancelled {
                model.send(key)
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
    }

    private func end() {
        isPressed = false
        repeatTask?.cancel()
        repeatTask = nil
    }
}

/// Balancim vertical: + em cima, legenda no meio, − embaixo (volume, canal).
struct Rocker: View {
    let up: RemoteKey
    let down: RemoteKey
    let upSymbol: String
    let downSymbol: String
    let caption: String

    var body: some View {
        VStack(spacing: 0) {
            RepeatKeyButton(key: up) { Image(systemName: upSymbol) }
            Text(caption)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.vertical, 4)
            RepeatKeyButton(key: down) { Image(systemName: downSymbol) }
        }
        .font(.system(size: 16, weight: .bold))
        .padding(.vertical, 6)
        .frame(width: 58, height: 132)
        .background {
            Capsule()
                .fill(Theme.keyGradient(Theme.key, pressed: false))
                .overlay(Capsule().stroke(Color.white.opacity(0.13), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
        }
    }
}
