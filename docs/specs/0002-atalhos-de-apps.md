# Spec 0002 — Atalhos de apps

| | |
|---|---|
| **Status** | Draft |
| **Autor** | Pedro |
| **Criada** | 2026-10-15 |
| **Depende de** | 0001 |

## Contexto

Hoje, para abrir Netflix/YouTube/Prime Video/globoplay o usuário precisa apertar Início e navegar na
TV com o D-pad — o mesmo atrito que o app inteiro existe para evitar. A TV já expõe, pelo WebSocket,
a lista de apps instalados e um comando de abertura (`docs/protocol/samsung-tizen-remote.md` §5).
Faltam só a UI e o fiação de protocolo.

## Objetivos

1. Mostrar uma linha de ícones de apps **favoritos** entre o cabeçalho e o D-pad.
2. Ao conectar, consultar a TV (`ed.installedApp.get`) para descobrir quais dos apps conhecidos
   (abaixo) estão instalados e qual `appId` real a TV usa para cada um.
3. Toque no ícone abre o app na TV (`ed.apps.launch`) usando esse `appId` real — sem navegação manual.
4. Deixar o usuário escolher, nas Preferências, quais desses apps viram favoritos.

## Apps conhecidos (bundlados no app)

Só estes quatro entram no v1 — mais apps é escopo de uma spec futura (basta bundlar um novo ícone
e uma nova chave, o mecanismo de baixo generaliza).

| Chave | Nome exibido | Ícone | `appId` de referência (comunidade — **não usado em runtime**, ver "Protocolo / dados") |
|---|---|---|---|
| `netflix` | Netflix | `docs/specs/assets/0002-icons/netflix.png` | `11101200001` / `3201907018807` |
| `youtube` | YouTube | `docs/specs/assets/0002-icons/youtube.png` | `111299001912` |
| `prime-video` | Prime Video | `docs/specs/assets/0002-icons/prime-video.png` | `3201512006785` / `3201910019365` |
| `globoplay` | globoplay | `docs/specs/assets/0002-icons/globoplay.png` | `3201908019022` |

Os `appId` de referência vêm de `xchwarze/samsung-tv-ws-api/APPLICATIONS.md` (comunidade, não
garantidos) — servem só de contexto de onde esses apps existem no catálogo Samsung. **O app nunca
usa esses valores para lançar um app**; ver próxima seção.

## Fora do escopo

- Grade/galeria completa de todos os apps instalados (só a linha de favoritos, só os 4 conhecidos).
- Apps além dos 4 listados acima.
- Abrir apps via REST (`POST /api/v2/applications/<appId>`) — a doc do protocolo já marca que
  firmwares 2021+ podem responder 404 nesse endpoint; usar só o WebSocket (`ed.apps.launch`).
- Detecção automática de "mais usados" — a escolha é manual.
- Instalar/desinstalar/atualizar apps.
- Lista de `appId` candidatos com tentativa múltipla — **não existe**: a TV sempre informa o `appId`
  real pelo próprio `ed.installedApp.get`, então não há ambiguidade de qual ID usar (ver abaixo).

## Experiência

### Linha de favoritos

- Nova linha no `RemoteView`, entre o cabeçalho e o D-pad (mesmo estilo de `KeyButton`).
- Até 4 ícones: um por chave conhecida que esteja **marcada como favorita** *e* **presente na
  última resposta** de `ed.installedApp.get`.
- Populada só depois que `ed.installedApp.get` responder; se não responder em ~2 s ou a TV não
  suportar o evento, a linha fica **oculta** — nunca bloqueia o resto do controle.
- Toque em um ícone → `ed.apps.launch` com o `appId` **que a TV retornou** para aquela chave. Sem
  spinner: mesmo padrão "fire-and-forget" das teclas normais.

### Preferências (⌘,) — nova seção "Apps"

- Lista só as chaves conhecidas que a última consulta confirmou instaladas, cada uma com um toggle
  "Favorito".
- Favoritos persistidos localmente por **chave** (`netflix`, não o `appId` cru — ele pode mudar
  entre firmwares, a chave não), ordenados pela ordem em que o usuário marcou.
- Se a consulta nunca respondeu (TV nunca conectou ainda): "Abra o controle conectado à TV para ver
  os apps disponíveis."
- Se respondeu mas nenhum dos 4 apps conhecidos foi encontrado: "Nenhum dos apps compatíveis foi
  encontrado nesta TV."

## Protocolo / dados

Referência: `docs/protocol/samsung-tizen-remote.md` §5. Formato de resposta confirmado em duas
implementações independentes da comunidade (`xchwarze/samsung-tv-ws-api/samsungtvws/event.py` e
`jaruba/ha-samsungtv-tizen/custom_components/samsungtv_tizen/media_player.py`) — não é mais
"inferido", mas também nunca foi capturado nesta TV específica (ver "Questões em aberto").

```json
{"method":"ms.channel.emit","params":{"event":"ed.installedApp.get","to":"host"}}
```
Resposta:
```json
{"event":"ed.installedApp.get","data":{"data":[{"appId":"...","name":"Netflix"}, ...]}}
```

**Resolução do `appId` (sem ambiguidade, sem tentativa múltipla):** para cada entrada da resposta,
normaliza `name` (lowercase + trim) e compara contra as 4 chaves conhecidas (também normalizadas:
`netflix`, `youtube`, `prime video`, `globoplay`). Quando bate, guarda em memória `chave → appId`
usando **o `appId` exato que a TV mandou** — nunca os valores de referência da tabela acima.

```json
{"method":"ms.channel.emit","params":{"event":"ed.apps.launch","to":"host",
  "data":{"appId":"<appId resolvido acima>","action_type":"DEEP_LINK","metaTag":""}}}
```
`action_type: "DEEP_LINK"` e `metaTag: ""` são os defaults usados por `samsungtvws`
(`ChannelEmitCommand.launch_app`) — o mesmo código-fonte comenta que alguns apps podem precisar
`NATIVE_LAUNCH`; risco aceito para v1, ver "Questões em aberto".

- `TVProtocol.swift` hoje só monta `ms.remote.control` (teclas). Precisa de um novo tipo
  `Encodable` para mensagens `ms.channel.emit` (ex.: `RemoteMessage.installedAppsRequest()`,
  `RemoteMessage.launchApp(appId:)`), seguindo o mesmo padrão de `sortedKeys`.
- Precisa de um novo tipo `Decodable` tolerante para a resposta de `ed.installedApp.get`: decodifica
  entradas com `appId` + `name` presentes, **descarta silenciosamente** entradas sem os dois (nunca
  lança erro por causa de uma entrada estranha no meio da lista).
- Persistência: lista (ordenada) de **chaves** favoritas em `UserDefaults`
  (`tv.apps.favorites.v1`), mesmo padrão de `ConfigurationStore`. O mapa `chave → appId` resolvido
  fica só em memória, re-consultado a cada conexão (o `appId` pode mudar entre firmwares — não faz
  sentido persistir um valor que pode ficar obsoleto).

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Ao conectar com sucesso, enviar `ed.installedApp.get`; aguardar resposta por até ~2 s. |
| FR-2 | Da resposta, extrair entradas com `appId`+`name`; normalizar `name` (lowercase+trim) e casar contra as 4 chaves conhecidas; guardar em memória o `appId` real de cada chave reconhecida. |
| FR-3 | Preferências → seção "Apps": toggle de favorito só para as chaves reconhecidas na última consulta; favoritos persistidos (ordenados) no UserDefaults por chave. |
| FR-4 | Mostrar linha de até 4 ícones de favoritos (chave bundlada, marcada como favorita e reconhecida na última consulta) entre o cabeçalho e o D-pad; ocultar a linha se não houver nenhum favorito reconhecido ou se a consulta não responder a tempo. |
| FR-5 | Toque num ícone envia `ed.apps.launch` com o `appId` resolvido (FR-2) daquela chave, `action_type: DEEP_LINK`, `metaTag: ""`. |
| FR-6 | Falha, timeout ou ausência do evento `ed.installedApp.get` não bloqueia nem atrasa o resto do controle — a linha de apps simplesmente não aparece. |

## Critérios de aceite

- [ ] Automatizado: decodificação de uma fixture (baseada no formato confirmado em
      `samsungtvws`/`ha-samsungtv-tizen`) com entradas reconhecidas, desconhecidas (ignoradas) e
      malformadas (descartadas); normalização e match de nome com variação de case/espaço; encoding
      de `ed.apps.launch`; ida e volta dos favoritos (por chave) no UserDefaults.
- [ ] Manual na TV: os apps realmente instalados na AU8000 aparecem em Preferências com os nomes
      certos; favoritos persistem entre reaberturas; toque abre o app certo; confirmar se os 4
      abrem com `DEEP_LINK` ou se algum precisa `NATIVE_LAUNCH`; linha some quando nenhum favorito
      está marcado.

## Plano de testes

**Automatizado** (`SamsungRemoteTests/`): fixture inventada mas grounded no formato confirmado pelas
duas libs de referência — cobrindo entrada reconhecida, entrada desconhecida, variação de
case/espaço no nome, entrada sem `appId` ou sem `name`; encode de `ed.apps.launch`; round-trip dos
favoritos por chave.

**Manual na TV** (`docs/tv/UN65AU8000GXZD.md`): capturar o payload real de `ed.installedApp.get` na
AU8000 (isso pode exigir ajuste no parser se o formato real divergir do grounded acima); confirmar
nomes exatos retornados para os 4 apps; confirmar `DEEP_LINK` vs `NATIVE_LAUNCH` por app; confirmar
visualmente se os 4 ícones cabem nos 288 pt de largura sem espremer o D-pad.

## Questões em aberto

- ⚠️ `ed.apps.launch` funciona de fato na AU8000, ou tem a mesma limitação que a doc do protocolo
  marca pro endpoint REST equivalente? Só a TV física confirma.
- ⚠️ Os 4 apps abrem todos com `action_type: DEEP_LINK`, ou algum precisa `NATIVE_LAUNCH`? O
  código-fonte de referência sugere que isso varia por app.
- Os nomes exatos que a AU8000 retorna para cada um dos 4 apps batem com o que normalizamos
  (`netflix`, `youtube`, `prime video`, `globoplay`)? Só validável na TV real — se não bater, o
  favorito correspondente simplesmente não aparece (falha silenciosa, consistente com FR-6).
