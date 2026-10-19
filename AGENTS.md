# AGENTS.md — Samsung Remote (macOS)

Guia operacional para agentes de código (Claude Code, Codex, Cursor etc.) e humanos.
Leia este arquivo inteiro antes de mudar qualquer coisa.

## O que é

App nativo de macOS (SwiftUI, menu bar) que funciona como controle remoto de uma
TV Samsung Tizen pela rede local. Ele usa a API WebSocket da TV na porta 8002, o REST
na porta 8001 e Wake-on-LAN. Não há servidor, cloud nem SDK de terceiros.

- TV de referência: **UN65AU8000GXZD** (AU8000, 2021, Tizen). Detalhes em `docs/tv/UN65AU8000GXZD.md`.
- Protocolo: `docs/protocol/samsung-tizen-remote.md`. **É a fonte da verdade** para o formato das mensagens.
- Arquitetura: `docs/architecture.md`.
- O que construir: `docs/specs/`. Por que foi decidido assim: `docs/decisions/`.

## Comandos

```bash
scripts/dev.sh build                 # xcodebuild Debug
scripts/dev.sh test                  # testes unitários (Swift Testing)
scripts/dev.sh run                   # build + abre o .app
scripts/dev.sh clean
scripts/dev.sh tv-info 192.168.0.50  # GET /api/v2/ da TV (modelo, PowerState, MAC)
scripts/dev.sh wake 80:47:86:xx:xx:xx # Wake-on-LAN pela linha de comando
```

Requisitos: macOS 14+ e Xcode 16+. O projeto usa *synchronized folders* (`objectVersion = 77`).
`xcbeautify` é opcional: se estiver instalado, o `scripts/dev.sh` usa.

## Fluxo de trabalho (spec-driven)

1. **Toda feature começa por uma spec** em `docs/specs/NNNN-titulo.md` (use `docs/specs/_template.md`).
   Se a tarefa não tem spec, escreva uma no status `Draft` e peça revisão antes de codar.
2. Implemente **só o que a spec pede**. Se precisar mudar o escopo, atualize a spec no mesmo PR.
3. Decisão de arquitetura não óbvia (dependência, formato de storage, mudança de protocolo)
   vira um ADR em `docs/decisions/NNNN-titulo.md`.
4. Ao terminar, marque os critérios de aceite da spec e mova o status (`Draft → Accepted → Implemented`).
5. Commits pequenos, em português ou inglês, no imperativo ("Adiciona atalho de canal").

### Definition of Done

- [ ] `scripts/dev.sh build` sem erros e sem warnings novos.
- [ ] `scripts/dev.sh test` passando; lógica nova (parsing, protocolo, estado) com teste.
- [ ] Critérios de aceite da spec atualizados.
- [ ] Docs atualizadas se o protocolo, os atalhos ou a arquitetura mudaram.
- [ ] Itens de "Teste manual na TV" listados no PR (o agente não tem acesso à TV, então o humano valida).

## Estrutura

```
SamsungRemote/            # target do app (pasta sincronizada: só criar arquivos aqui)
  App/                    # entry point + RemoteModel (estado, @MainActor @Observable)
  Core/TV/                # protocolo: teclas, mensagens, WebSocket, REST, Wake-on-LAN
  Core/Storage/           # UserDefaults (config) + Keychain (token)
  UI/                     # SwiftUI: RootView, RemoteView, SettingsView, Theme
  UI/Components/          # DPad, KeyButton, RepeatKeyButton, Rocker
  Resources/              # Assets.xcassets (AppIcon, AccentColor)
SamsungRemoteTests/       # Swift Testing (pasta sincronizada)
Config/                   # Info.plist parcial + entitlements (fora das pastas sincronizadas)
docs/                     # protocolo, TV, arquitetura, specs, ADRs
scripts/                  # utilitários de diagnóstico (sem dependências)
```

## Regras do projeto Xcode

- **Não edite `project.pbxproj` para adicionar arquivos.** As pastas `SamsungRemote/` e
  `SamsungRemoteTests/` são sincronizadas: basta criar o `.swift` dentro delas.
- Não coloque `.md`, `.plist` ou `.entitlements` dentro de `SamsungRemote/`, porque iriam como resource.
  Configuração fica em `Config/`.
- Só edite o `pbxproj` para mudar build settings, e mantenha Debug e Release coerentes.
- Assinatura é "Sign to Run Locally" (`CODE_SIGN_IDENTITY = "-"`, sem team). Não coloque Team ID no repo.

## Convenções de código

- Swift 5 language mode, macOS 14+. Sem dependências externas (SPM/CocoaPods). Ver ADR 0001.
- Estado de UI: `RemoteModel` (`@MainActor @Observable`), injetado com `.environment(model)`.
- Rede fica em `Core/TV`, sem import de SwiftUI. UI não fala com `URLSession` diretamente.
- Mensagens da TV são montadas por `RemoteMessage` (Encodable, `sortedKeys`). Não monte JSON por interpolação de string.
- Novas teclas: adicione em `RemoteKey` com o código exato do protocolo e documente na tabela do protocolo.
- Textos de UI em português (pt-BR). Identificadores e comentários de código podem ser em português.
- Erros visíveis ao usuário via `TVConnectionError.errorDescription`, curtos e acionáveis.
- Testes com Swift Testing (`import Testing`, `@Test`, `#expect`). Fixtures sem dados reais.

## Segurança e privacidade

- **Nunca** commite token de pareamento, número de série, MAC real ou IP público.
  O token vai para o Keychain; IP e MAC vão para o UserDefaults do sandbox.
- O certificado autoassinado da TV só é aceito para o host configurado (`TVWebSocketClient`).
  Não generalize isso para "aceitar qualquer certificado".
- Entitlements mínimos: sandbox + `network.client` + `network.server` (SSDP, ver ADR 0004).
  Justifique em ADR qualquer adição nova.

## Limites do agente

- Você não consegue testar contra a TV real. Para qualquer coisa que dependa dela
  (pareamento, Wake-on-LAN, nova tecla), deixe um checklist de teste manual no PR.
- Não mude `RemoteModel.clientName`: isso invalida o pareamento existente na TV.
- Em caso de dúvida sobre o comportamento da TV, consulte `docs/protocol/` e cite a fonte.
  Se não houver fonte, marque como "a validar na TV" na spec em vez de assumir.
