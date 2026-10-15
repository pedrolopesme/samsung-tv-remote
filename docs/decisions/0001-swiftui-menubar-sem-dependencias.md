# ADR 0001 — SwiftUI, app de menu bar, sem dependências

**Status:** Accepted · 2026-10-14

## Contexto
O app é um controle remoto: precisa abrir rápido, ficar à mão e ser pequeno. O protocolo da TV é
simples (WebSocket + JSON + UDP), e o Foundation já cobre tudo (`URLSessionWebSocketTask`, `URLSession`, sockets BSD).

## Decisão
- SwiftUI com `MenuBarExtra(.window)` como interface principal; `LSUIElement = YES` (sem Dock).
- macOS 14+ para usar `@Observable`, `onKeyPress`, `SettingsLink` e `focusEffectDisabled`.
- **Zero dependências de terceiros.** Nada de Starscream, Alamofire etc.
- Swift 5 language mode por enquanto. Migrar para Swift 6 (strict concurrency) vira um ADR próprio.

## Consequências
- Build reprodutível sem resolver pacotes; agentes não precisam de rede para compilar.
- Implementamos à mão o trust do certificado autoassinado e o Wake-on-LAN (pouco código e testado).
- Sem suporte a macOS 13 ou anterior.
