# Spec 0002 — Atalhos de apps

| | |
|---|---|
| **Status** | Draft |
| **Autor** | Pedro |
| **Criada** | 2026-10-15 |
| **Depende de** | 0001 |

## Contexto

Hoje, para abrir Netflix/YouTube/Globoplay/Prime o usuário precisa apertar Início e navegar na TV
com o D-pad — o mesmo atrito que o app inteiro existe para evitar. A TV já expõe, pelo WebSocket,
a lista de apps instalados e um comando de abertura (`docs/protocol/samsung-tizen-remote.md` §5).
Faltam só a UI e o fiação de protocolo.

## Objetivos

1. Mostrar uma linha de ícones de apps **favoritos** entre o cabeçalho e o D-pad.
2. Ao conectar, consultar a TV (`ed.installedApp.get`) para descobrir quais apps existem e seus `appId`.
3. Toque no ícone abre o app na TV (`ed.apps.launch`), sem navegação manual.
4. Deixar o usuário escolher, nas Preferências, quais apps instalados viram favoritos (a tela tem
   288 pt de largura — não cabe grade completa).

## Fora do escopo

- Grade/galeria completa de todos os apps instalados (só a linha de favoritos).
- Abrir apps via REST (`POST /api/v2/applications/<appId>`) — a doc do protocolo já marca que
  firmwares 2021+ podem responder 404 nesse endpoint; usar só o WebSocket (`ed.apps.launch`).
- Detecção automática de "mais usados" — nesta spec a escolha é manual.
- Instalar/desinstalar/atualizar apps.
- Ícones baixados da TV (ver "Questões em aberto") — v1 pode usar só o nome ou um SF Symbol genérico.

## Experiência

### Linha de favoritos

- Nova linha no `RemoteView`, entre o cabeçalho e o D-pad (mesmo estilo de `KeyButton`).
- Populada só depois que `ed.installedApp.get` responder; se não responder em ~2 s ou a TV não
  suportar o evento, a linha fica **oculta** — nunca bloqueia o resto do controle.
- Toque em um ícone → `ed.apps.launch` com o `appId` correspondente. Sem spinner: mesmo padrão
  "fire-and-forget" das teclas normais.

### Preferências (⌘,) — nova seção "Apps"

- Lista os apps instalados (do último `ed.installedApp.get` bem-sucedido) com um toggle "Favorito".
- Favoritos persistidos localmente, ordenados pela ordem em que o usuário marcou.
- Se a lista de apps instalados nunca chegou (TV não respondeu ainda), mostrar
  "Abra o controle conectado à TV para ver os apps disponíveis."

## Protocolo / dados

Referência: `docs/protocol/samsung-tizen-remote.md` §5.

```json
{"method":"ms.channel.emit","params":{"event":"ed.installedApp.get","to":"host"}}
```
Resposta esperada (⚠️ formato inferido, não validado na AU8000 — ver "Questões em aberto"):
```json
{"event":"ed.installedApp.get","data":{"data":[{"appId":"...","name":"Netflix", "...":"..."}]}}
```

```json
{"method":"ms.channel.emit","params":{"event":"ed.apps.launch","to":"host",
  "data":{"appId":"<id>","action_type":"DEEP_LINK"}}}
```

- `TVProtocol.swift` hoje só monta `ms.remote.control` (teclas). Precisa de um novo tipo
  `Encodable` para mensagens `ms.channel.emit` (ex.: `RemoteMessage.installedAppsRequest()`,
  `RemoteMessage.launchApp(appId:)`), seguindo o mesmo padrão de `sortedKeys` (nada de
  interpolação de string).
- Precisa de um novo tipo `Decodable` para a resposta de `ed.installedApp.get` (hoje só
  `ChannelEvent` existe, e só decodifica `token` de `ms.channel.connect`).
- Persistência: lista de `appId` favoritos (ordenada) em `UserDefaults`, chave nova
  (ex.: `tv.apps.favorites.v1`), mesmo padrão de `ConfigurationStore`. A lista de apps
  *instalados* (não-favoritos) fica só em memória — não precisa persistir, é re-consultada
  a cada conexão.

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Ao conectar com sucesso, enviar `ed.installedApp.get` e guardar a lista de apps instalados em memória. |
| FR-2 | Preferências → seção "Apps": marcar/desmarcar favoritos a partir da lista de apps instalados. |
| FR-3 | Persistir a lista (ordenada) de `appId` favoritos no UserDefaults. |
| FR-4 | Mostrar uma linha de ícones de favoritos entre o cabeçalho e o D-pad; ocultar a linha se não houver favoritos ou se `ed.installedApp.get` não responder. |
| FR-5 | Toque num ícone envia `ed.apps.launch` com o `appId` e `action_type: DEEP_LINK`. |
| FR-6 | Falha ou timeout de `ed.installedApp.get` não deve bloquear nem atrasar o resto do controle. |

## Critérios de aceite

- [ ] Automatizado: decodificação de uma fixture de resposta de `ed.installedApp.get`, encoding de `ed.apps.launch`, round-trip dos favoritos no UserDefaults.
- [ ] Manual na TV: lista de apps aparece corretamente na AU8000; favoritos persistem entre reaberturas; toque abre o app certo; comportamento ao desmarcar todos os favoritos (linha some).

## Plano de testes

**Automatizado** (`SamsungRemoteTests/`): fixture do payload de `ed.installedApp.get` (precisa ser
capturada na TV real primeiro — ver questão em aberto), encode de `ed.apps.launch`, ida e volta dos
favoritos no `UserDefaults`.

**Manual na TV:** adicionar checklist em `docs/tv/UN65AU8000GXZD.md` depois que o payload real for
capturado.

## Questões em aberto

- ⚠️ O formato exato da resposta de `ed.installedApp.get` nunca foi capturado nesta TV (nomes de
  campo, se vem ícone ou só nome/`appId`). Precisa validar manualmente antes de escrever o parser
  final — por ora o parser deve ser tolerante a campos desconhecidos.
- ⚠️ `ed.apps.launch` funciona de fato na AU8000, ou essa TV também tem as limitações que a doc do
  protocolo marca pro endpoint REST equivalente? Só dá pra confirmar na TV física.
- A TV manda alguma imagem/URL de ícone do app, ou só texto? Se só texto, a UI usa label ou um
  SF Symbol genérico por enquanto (Netflix, YouTube etc. não têm symbol nativo da Apple).
- Quantos favoritos cabem nos 288 pt de largura sem espremer o D-pad? Precisa de um protótipo visual
  antes de travar o número máximo.
