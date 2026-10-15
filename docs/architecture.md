# Arquitetura

```
┌──────────────────────────── UI (SwiftUI) ─────────────────────────────┐
│ SamsungRemoteApp ─ MenuBarExtra(.window) ─ RootView                   │
│                     ├─ SetupView      (sem TV configurada)            │
│                     └─ RemoteView     (DPad, KeyButton, Rocker…)      │
│                    Settings ─ SettingsView                            │
└───────────────┬───────────────────────────────────────────────────────┘
                │ .environment(model)   model.send(.volumeUp)
┌───────────────▼──────────── App (estado) ─────────────────────────────┐
│ RemoteModel  @MainActor @Observable                                   │
│  status · configuration · errorMessage                                │
│  setUp(host:) · connect() · send(_:) · togglePower() · powerOn()      │
└──────┬──────────────────┬──────────────────────┬──────────────────────┘
       │                  │                      │
┌──────▼──────┐  ┌────────▼─────────┐  ┌─────────▼──────────┐
│ Core/TV     │  │ Core/TV          │  │ Core/Storage       │
│ TVInfoClient│  │ TVWebSocketClient│  │ ConfigurationStore │ UserDefaults
│ REST :8001  │  │ WSS :8002        │  │ KeychainTokenStore │ Keychain
│ WakeOnLAN   │  │ RemoteMessage    │  └────────────────────┘
│ UDP :9      │  │ ChannelEvent     │
└─────────────┘  └──────────────────┘
```

## Princípios

- **Core não conhece UI.** `Core/` só importa Foundation, Security e Darwin, então dá para testar sem SwiftUI.
- **Um dono de estado.** Só o `RemoteModel` muda o status da conexão. As views são funções dele.
- **Conexão preguiçosa.** Ninguém precisa "conectar antes": `send(_:)` conecta se for preciso.
- **Falha visível e acionável.** Todo erro vira `errorMessage` com o que fazer a seguir.

## Fluxo de uma tecla

1. `KeyButton` → `Haptics.tap()` + `model.send(.volumeUp)`.
2. `RemoteModel.sendNow`: sem `client`, chama `connect()`. Conexões concorrentes reaproveitam a mesma `Task`.
3. `connect()` faz o REST de health check (2 s), abre o WebSocket com o token do Keychain e espera `ms.channel.connect`.
4. `RemoteMessage.key(.volumeUp)` gera o JSON e `TVWebSocketClient.send` o envia.
5. Em falha: `handleDisconnect`, reconecta uma vez e reenvia.

## Onde mexer

| Quero… | Arquivo(s) |
|---|---|
| Adicionar uma tecla | `Core/TV/RemoteKey.swift` + tabela em `docs/protocol/…` + botão em `UI/RemoteView.swift` |
| Mudar o visual | `UI/Theme.swift` (tokens) e `UI/Components/` |
| Novo atalho de teclado | `KeyboardShortcuts` em `UI/RemoteView.swift` + tabela em `SettingsView` + spec |
| Novo evento da TV | `ChannelEvent` em `Core/TV/TVProtocol.swift` + teste |
| Persistir algo novo | `Core/Storage/Storage.swift` (segredo → Keychain; resto → UserDefaults) |
