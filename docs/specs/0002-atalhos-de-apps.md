# Spec 0002 — Atalhos de apps

| | |
|---|---|
| **Status** | Accepted (REST validado na AU8000 real; UI e persistência de favoritos ainda não testadas ponta a ponta) |
| **Autor** | Pedro |
| **Criada** | 2026-10-15 |
| **Depende de** | 0001 |

## Contexto

Hoje, para abrir Netflix/YouTube/Prime Video/globoplay o usuário precisa apertar Início e navegar na
TV com o D-pad — o mesmo atrito que o app inteiro existe para evitar.

**Mudança de rota em relação à primeira versão desta spec:** a ideia original era usar o canal
WebSocket (`ed.installedApp.get`/`ed.apps.launch`, documentado em `docs/protocol/samsung-tizen-remote.md`
§5 e usado por `samsungtvws`/Home Assistant). Testado ao vivo na AU8000 (TV 2021), **nenhum dos
dois funciona**:

- `ed.installedApp.get` é aceito pelo transporte (`ms.channel.emit` é um método válido) e **ignorado
  em silêncio** — nenhum handler escuta esse evento nessa geração de firmware.
- `ms.application.get` (método de topo, alternativa cogitada) retorna
  `{"event":"ms.error","data":{"message":"unrecognized method value : ms.application.get"}}`.
- `ed.apps.launch` (WebSocket) não abriu nada na TV.

Em compensação, a **REST** (`GET`/`POST http://<host>:8001/api/v2/applications/<appId>`) funciona
perfeitamente — testado ao vivo, ver "Protocolo / dados". O protocolo doc marcava essa rota com
⚠️ "alguns firmwares 2021+ retornam 404"; não é o caso da AU8000.

## Objetivos

1. Mostrar uma linha de ícones de apps **favoritos** no rodapé do controle, acima de Preferências/Sair.
2. Ao conectar, descobrir via REST quais dos apps conhecidos (abaixo) a TV reconhece, testando os
   `appId` candidatos de cada um.
3. Toque no ícone abre o app na TV (`POST` REST) usando o `appId` confirmado — sem navegação manual.
4. Deixar o usuário escolher, nas Preferências, quais desses apps viram favoritos.

## Apps conhecidos (bundlados no app)

Só estes quatro entram no v1 — mais apps é escopo de uma spec futura (basta bundlar um novo ícone
e uma nova chave, o mecanismo de baixo generaliza).

| Chave | Nome exibido | Ícone | `appId` candidatos (ordem de prioridade) | Confirmado na AU8000 |
|---|---|---|---|---|
| `netflix` | Netflix | `docs/specs/assets/0002-icons/netflix.png` | `3201907018807`, `11101200001`, `org.tizen.netflixapp` | ✅ 200, `running:true` |
| `youtube` | YouTube | `docs/specs/assets/0002-icons/youtube.png` | `111299001912`, `9Ur5IzDKqV.TizenYouTube` | ✅ 200, `running:true` |
| `prime-video` | Prime Video | `docs/specs/assets/0002-icons/prime-video.png` | `3201910019365`, `3201512006785`, `org.tizen.primevideo`, `org.tizen.ignition` | ✅ 200, `running:false` |
| `globoplay` | globoplay | `docs/specs/assets/0002-icons/globoplay.png` | `3201908019022`, `org.tizen.globoplayapp` | ❌ 404 nos dois, mesmo com o app instalado e aberto (ver "Questões em aberto") |

Ícones: arte oficial da Smart Hub (mesmo CDN que a própria página de catálogo da Samsung usa —
`d1oxlq5h9kq8q5.cloudfront.net/tvstore/contents/<appId>/icon_*.png`), não logos genéricos — fica
mais fiel ao que já aparece na tela da TV.

IDs candidatos vêm de `xchwarze/samsung-tv-ws-api/APPLICATIONS.md` e
`blog-razrabotchika/homebridge-samsung-tizen-applications` (comunidade, não garantidos — "IDs can
change over time and can differ by TV year / Tizen version"). Por isso cada app pode ter mais de
um candidato: o primeiro que a TV confirmar (`GET` 200) vira o `appId` usado.

## Fora do escopo

- Grade/galeria completa de todos os apps instalados (só a linha de favoritos, só os 4 conhecidos).
- Apps além dos 4 listados acima.
- O canal WebSocket `ed.*` para descoberta/lançamento — confirmado morto nesta geração de firmware
  (ver "Contexto"). Mantido documentado em `docs/protocol/samsung-tizen-remote.md` para TVs mais
  antigas (K+ 2016–2017, ⚠️ não testado), mas esta spec não depende dele.
- Detecção automática de "mais usados" — a escolha é manual.
- Instalar/desinstalar/atualizar apps.

## Experiência

### Linha de favoritos

- Nova linha no `RemoteView`, no rodapé do controle, acima de Preferências/Reconectar/Sair.
  Cada ícone é um "tile" retangular com a arte oficial da Smart Hub, não um glyph numa keycap
  redonda — mais fiel ao visual real da TV.
- Até 4 ícones: um por chave conhecida que esteja **marcada como favorita** *e* **confirmada via
  REST** na conexão atual.
- Populada de forma assíncrona depois de conectar; se a TV não confirmar nenhum app (REST falhar
  ou todos os candidatos derem 404), a linha fica **oculta** — nunca bloqueia o resto do controle.
- Toque em um ícone → `POST` REST com o `appId` confirmado para aquela chave. Sem spinner: mesmo
  padrão "fire-and-forget" das teclas normais.

### Preferências (⌘,) — nova seção "Apps"

- Lista só as chaves conhecidas que a última consulta confirmou (REST 200), cada uma com um toggle
  "Favorito".
- Favoritos persistidos localmente por **chave** (`netflix`, não o `appId` cru — ele pode mudar
  entre firmwares/anos, a chave não), ordenados pela ordem em que o usuário marcou.
- Se a consulta nunca respondeu (TV nunca conectou ainda): "Abra o controle conectado à TV para ver
  os apps disponíveis."
- Se respondeu mas nenhum dos 4 apps conhecidos foi encontrado: "Nenhum dos apps compatíveis foi
  encontrado nesta TV."

## Protocolo / dados

**Validado ao vivo na AU8000** (`192.168.68.109`, 2026-10-15):

```
GET  http://<host>:8001/api/v2/applications/<appId>
→ 200 {"id":"3201907018807","name":"Netflix","running":true,"version":"70.23.15090","visible":false}
→ 404 {"code":404,"message":"Not found error.","status":404}   (appId inexistente nesta TV)

POST http://<host>:8001/api/v2/applications/<appId>
→ 200 true   (lança o app — confirmado abrindo a Netflix de verdade)
```

**Resolução do `appId` (por app, sem ambiguidade de lançamento):** para cada `KnownApp`, testa seus
`candidateAppIds` em ordem via `GET` até um responder 200; esse é o `appId` resolvido para aquela
TV. Testar é **sem efeito colateral** (`GET` não lança nada), diferente da ideia descartada no grill
desta spec de "disparar `ed.apps.launch` pra todos os candidatos às cegas".

- `TVEndpoint.applicationURL(host:appId:)` monta a URL; `TVApplicationClient.isAvailable`/`.launch`
  fazem o `GET`/`POST`. Mesmo padrão de `TVInfoClient` (REST simples via `URLSession.shared`).
- Resolução roda em paralelo para os 4 apps (`withTaskGroup`), sem bloquear o resto do controle
  (FR-1/FR-6).
- Persistência: lista (ordenada) de **chaves** favoritas em `UserDefaults` (`tv.apps.favorites.v1`),
  mesmo padrão de `ConfigurationStore`. O mapa `chave → appId` resolvido fica só em memória,
  re-consultado a cada conexão (o `appId` pode mudar entre firmwares).

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Ao conectar com sucesso, testar via `GET` REST os `candidateAppIds` de cada app conhecido, em paralelo. |
| FR-2 | Guardar em memória o primeiro `appId` candidato que responder 200 (REST) para cada app conhecido. |
| FR-3 | Preferências → seção "Apps": toggle de favorito só para as chaves confirmadas na última consulta; favoritos persistidos (ordenados) no UserDefaults por chave. |
| FR-4 | Mostrar linha de até 4 ícones de favoritos (chave bundlada, marcada como favorita e confirmada na última consulta) no rodapé do controle, acima de Preferências/Sair; ocultar a linha se não houver nenhum favorito confirmado. |
| FR-5 | Toque num ícone envia `POST` REST com o `appId` resolvido (FR-2) daquela chave. |
| FR-6 | Falha de rede ou nenhum app confirmado não bloqueia nem atrasa o resto do controle — a linha de apps simplesmente não aparece. |

## Critérios de aceite

- [x] Automatizado: `TVEndpoint.applicationURL` gera a URL correta; rejeita host/appId inválido;
      todo `KnownApp` tem ao menos um candidato; round-trip dos favoritos (por chave) no UserDefaults.
- [x] REST validado na TV real: `GET`/`POST` confirmados funcionando (Netflix abriu de verdade).
- [ ] Manual na TV, ponta a ponta pela UI do app: favoritar na seção "Apps", confirmar que a linha
      de ícones aparece no controle, tocar e confirmar que abre o app certo.

## Plano de testes

**Automatizado** (`SamsungRemoteTests/AppShortcutsTests.swift`): construção de URL REST, validação
de `KnownApp.all`, round-trip de favoritos. Chamadas de rede reais (`TVApplicationClient`) não são
testadas em automatizado — mesma convenção de `TVInfoClient`, que também não tem teste unitário de
rede, só de construção de URL.

**Manual na TV** (`docs/tv/UN65AU8000GXZD.md`): já confirmado por fora da UI (`curl` direto) que
`GET`/`POST` funcionam para Netflix/YouTube/Prime Video. Falta: favoritar pela UI do app e confirmar
visualmente que a linha aparece e lança o app certo; verificar se mais candidatos de `appId` são
necessários para globoplay (404 com o único ID conhecido).

## Questões em aberto

- `globoplay` não resolve nesta TV mesmo com o app **instalado e aberto de verdade** — investigado
  a fundo: o `appId` `3201908019022` é confirmado pelo **catálogo oficial da Samsung Brasil**
  (nome, versão, atualizado 10/2025) e mesmo assim dá 404; o alias `org.tizen.globoplayapp` também.
  Até o plugin Homebridge mais usado (677★) depende do mesmo `ed.installedApp.get` morto pra listar
  apps — não é uma alternativa. Conclusão: essa TV provavelmente roda um `appId` regional/de lote
  específico da Samsung Brasil, não documentado em nenhuma base pública. O único caminho confiável
  pra descobrir é o Tizen Studio (Device Manager → "Installed Web App List" → `App ID - WAS`),
  que exige Modo Desenvolvedor na TV — fora do alcance de um agente sem acesso físico. Decisão:
  aceito como está — falha silenciosa por design (FR-6), revisitar se alguém achar o ID real.
