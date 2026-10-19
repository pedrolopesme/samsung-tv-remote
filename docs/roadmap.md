# Roadmap

Candidatas a próximas specs, em ordem de valor percebido. Cada uma vira `docs/specs/NNNN-*.md` antes de ser implementada.

| # | Feature | Notas |
|---|---|---|
| 0003 | **Atalhos globais e teclas de mídia** | Volume e play/pause do Mac controlando a TV, mesmo com o popover fechado. Precisa de opt-in. |
| 0004 | **Descoberta automática** | SSDP (`urn:samsung.com:device:RemoteControlReceiver:1`) para listar TVs na rede no onboarding. |
| 0005 | **Teclado / envio de texto** | `ms.remote.control` com `TypeOfRemote: SendInputString` (Base64) para campos de busca. ⚠️ validar |
| 0006 | **Trackpad como D-pad** | Gestos de swipe no popover → setas; clique → OK. |
| 0007 | **Janela destacável / sempre no topo** | Controle flutuante enquanto se assiste. |
| 0008 | **Múltiplas TVs** | Seletor no cabeçalho; token por TV já é suportado pelo Keychain. |
| 0009 | **Shortcuts.app / App Intents** | "Ligar TV", "Volume +5" via Atalhos e Siri. |
