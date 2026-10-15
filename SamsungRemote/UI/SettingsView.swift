import SwiftUI

/// Preferências (⌘,): IP, MAC para Wake-on-LAN, re-pareamento e atalhos.
struct SettingsView: View {
    @Environment(RemoteModel.self) var model
    @State var host = ""
    @State var macAddress = ""

    var body: some View {
        Form {
            if let configuration = model.configuration {
                Section("TV") {
                    LabeledContent("Nome", value: configuration.displayName)
                    LabeledContent("Modelo", value: configuration.modelName ?? "—")
                    LabeledContent("Status", value: model.status.title)
                    TextField("Endereço IP", text: $host)
                    TextField("Endereço MAC (Wake-on-LAN)", text: $macAddress, prompt: Text("80:47:86:00:00:00"))
                }

                Section {
                    HStack {
                        Button("Salvar") {
                            model.updateConfiguration(host: host, macAddress: macAddress)
                        }
                        .keyboardShortcut(.defaultAction)
                        Button("Parear novamente") { model.resetPairing() }
                        Spacer()
                        Button("Esquecer TV", role: .destructive) { model.forgetTV() }
                    }
                }
            } else {
                Section {
                    Text("Nenhuma TV configurada. Abra o controle no menu bar para conectar.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Atalhos de teclado (com o controle aberto)") {
                ForEach(Self.shortcuts) { shortcut in
                    LabeledContent(shortcut.action) {
                        Text(shortcut.keys).font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onAppear(perform: load)
        .onChange(of: model.configuration) { load() }
    }

    private func load() {
        host = model.configuration?.host ?? ""
        macAddress = model.configuration?.macAddress ?? ""
    }

    struct Shortcut: Identifiable {
        let keys: String
        let action: String
        var id: String { keys }
    }

    static let shortcuts: [Shortcut] = [
        Shortcut(keys: "← ↑ → ↓", action: "Navegar"),
        Shortcut(keys: "⏎", action: "OK"),
        Shortcut(keys: "⌫", action: "Voltar"),
        Shortcut(keys: "H", action: "Início"),
        Shortcut(keys: "+ / −", action: "Volume"),
        Shortcut(keys: "M", action: "Mudo"),
        Shortcut(keys: "[ / ]", action: "Canal"),
        Shortcut(keys: "Espaço / P", action: "Play / Pause"),
        Shortcut(keys: "0–9", action: "Números"),
    ]
}
