import AppKit
import SwiftUI

/// Conteúdo da janela do menu bar: onboarding até existir uma TV configurada, depois o controle.
struct RootView: View {
    @Environment(RemoteModel.self) var model

    var body: some View {
        Group {
            if model.configuration == nil {
                SetupView()
            } else {
                RemoteView()
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Primeiro uso: pede o IP da TV e dispara o pareamento. Descobre candidatas via SSDP em
/// paralelo (spec 0003) — nunca bloqueia nem substitui a entrada manual.
struct SetupView: View {
    @Environment(RemoteModel.self) var model
    @State var host = ""
    @State private var isSearching = true
    @State private var discovered: [DiscoveredTV] = []

    /// Verdadeiro enquanto o campo bate exatamente com a única TV descoberta — some assim que o
    /// usuário edita o campo (FR-3).
    private var isFromDiscovery: Bool {
        discovered.count == 1 && host == discovered[0].host
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "av.remote")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Conecte sua TV")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.label)
                Text("Digite o IP da TV Samsung. Ele aparece em Configurações › Geral › Rede › Status da rede › Configurações de IP.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("192.168.0.50", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))
                    .onSubmit(connect)
                    .overlay {
                        if isFromDiscovery {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Theme.accent, lineWidth: 2)
                        }
                    }

                if isSearching {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("Procurando TVs na rede…")
                    }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.secondaryLabel)
                } else if isFromDiscovery {
                    Label("TV encontrada na rede · IP preenchido", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.success)
                } else if discovered.count > 1 {
                    Text("\(discovered.count) TVs Samsung encontradas · clique para usar")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.secondaryLabel)
                    VStack(spacing: 4) {
                        ForEach(discovered) { tv in
                            DiscoveryRow(tv: tv) {
                                host = tv.host
                                discovered = [tv]
                            }
                        }
                    }
                }
            }

            Button(action: connect) {
                HStack(spacing: 8) {
                    if model.isBusy { ProgressView().controlSize(.small) }
                    Text(buttonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.ok)
            .disabled(host.isEmpty || model.isBusy)

            if let message = model.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Na primeira conexão a TV pergunta se permite o \"\(RemoteModel.clientName)\". Aceite com o controle físico.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryLabel)
            }
        }
        .padding(22)
        .frame(width: Theme.remoteWidth)
        .background(Theme.bodyGradient)
        .task {
            let found = await SSDPDiscovery.discover()
            discovered = found
            isSearching = false
            if found.count == 1, host.isEmpty {
                host = found[0].host
            }
        }
    }

    private var buttonTitle: String {
        switch model.status {
        case .awaitingApproval: "Aceite na TV…"
        case .connecting: "Procurando a TV…"
        default: "Conectar"
        }
    }

    private func connect() {
        guard !host.isEmpty else { return }
        Task { await model.setUp(host: host) }
    }
}

/// Uma linha da lista de "várias TVs encontradas" — hover revela o rótulo "usar" (FR-4).
private struct DiscoveryRow: View {
    let tv: DiscoveredTV
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tv.host)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.label)
                    Text("Samsung · UPnP :\(tv.port)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.secondaryLabel)
                }
                Spacer()
                if isHovering {
                    Text("usar")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
