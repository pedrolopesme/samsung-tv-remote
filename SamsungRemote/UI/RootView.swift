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

/// Primeiro uso: pede o IP da TV e dispara o pareamento.
struct SetupView: View {
    @Environment(RemoteModel.self) var model
    @State var host = ""

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

            TextField("192.168.0.50", text: $host)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .monospaced))
                .onSubmit(connect)

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
