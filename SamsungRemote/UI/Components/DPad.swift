import SwiftUI

/// Anel direcional com OK central, no formato do controle físico da Samsung.
struct DPad: View {
    @Environment(RemoteModel.self) var model

    var diameter: CGFloat = 200

    var body: some View {
        ZStack {
            ring

            ForEach(Direction.allCases) { direction in
                Button {
                    Haptics.tap()
                    model.send(direction.key)
                } label: {
                    Image(systemName: direction.symbol)
                        .font(.system(size: 15, weight: .heavy))
                        .frame(width: 62, height: 62)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ArrowStyle())
                .offset(direction.offset(distance: diameter * 0.355))
                .help(direction.key.title)
                .accessibilityLabel(direction.key.title)
            }

            KeyButton(key: .enter, tint: Theme.ok) {
                Text("OK").font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .frame(width: diameter * 0.40, height: diameter * 0.40)
        }
        .frame(width: diameter, height: diameter)
    }

    private var ring: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.key, Theme.keyRing],
                    center: .init(x: 0.5, y: 0.35),
                    startRadius: diameter * 0.1,
                    endRadius: diameter * 0.6
                )
            )
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .overlay(
                // Sulco entre o anel e o OK
                Circle()
                    .stroke(Color.black.opacity(0.45), lineWidth: 6)
                    .frame(width: diameter * 0.46, height: diameter * 0.46)
                    .blur(radius: 2)
            )
            .shadow(color: .black.opacity(0.55), radius: 10, y: 6)
    }
}

private struct ArrowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.accent : Theme.label)
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.8 : 0), radius: 8)
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private enum Direction: CaseIterable, Identifiable {
    case up, down, left, right

    var id: Self { self }

    var key: RemoteKey {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
    }

    var symbol: String {
        switch self {
        case .up: "chevron.up"
        case .down: "chevron.down"
        case .left: "chevron.left"
        case .right: "chevron.right"
        }
    }

    func offset(distance: CGFloat) -> CGSize {
        switch self {
        case .up: CGSize(width: 0, height: -distance)
        case .down: CGSize(width: 0, height: distance)
        case .left: CGSize(width: -distance, height: 0)
        case .right: CGSize(width: distance, height: 0)
        }
    }
}
