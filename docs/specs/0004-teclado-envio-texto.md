# Spec 0004 — Teclado / envio de texto

| | |
|---|---|
| **Status** | Implemented — confirmado na AU8000 real (2026-10-20): funciona em campos nativos do Tizen (busca do Smart Hub), **não funciona em apps de streaming de terceiros** (YouTube, Prime Video — ver "Fora do escopo") |
| **Autor** | Pedro |
| **Criada** | 2026-10-20 |
| **Depende de** | 0001 |

## Contexto

Campos de busca na TV hoje só dá pra preencher letra por letra com o D-pad no teclado virtual —
lento e desconfortável. A API `ms.remote.control` tem um modo `SendInputString` que manda o texto
inteiro de uma vez, em Base64. É o item 0004 do roadmap, marcado "⚠️ validar": o formato vinha de
implementações de terceiros (`samsungtvws`), nunca tinha sido testado contra a AU8000 real.

**Confirmado na TV real** (ver "Protocolo / dados" e `docs/protocol/samsung-tizen-remote.md` §3):
funciona nos campos nativos do Tizen (ex. busca do Smart Hub). **Não funciona** nos apps de
streaming de terceiros citados na proposta original (YouTube, Prime Video testados; Netflix não
testado mas mesmo padrão esperado) — esses apps renderizam o próprio teclado virtual dentro da UI,
sem usar o IME nativo do Tizen, então não existe campo de sistema focado pra injetar o texto. Não é
bug do app: é limitação de arquitetura de cada app de streaming, documentada em "Fora do escopo".

## Objetivos

1. Deixar o usuário digitar um texto no Mac (teclado físico) e mandar pra TV de uma vez, pro campo
   que estiver focado lá.
2. Fechar o teclado virtual da TV ao terminar (`SendInputEnd`), se confirmado que isso é necessário/
   funciona.
3. Continuar funcionando com os atalhos de D-pad existentes — texto é um modo adicional, não troca
   nada do MVP (spec 0001).

## Fora do escopo

- Detectar automaticamente quando um campo de texto está focado na TV via `ms.remote.imeStart`/
  `ms.remote.imeEnd` pra abrir o teclado do app sozinho. O usuário abre o teclado manualmente.
- **Apps de streaming de terceiros (YouTube, Prime Video, provavelmente Netflix)** — ⚠️ **confirmado
  que não funciona** na AU8000 real (2026-10-20): esses apps implementam o próprio teclado virtual
  dentro da UI (grade de botões navegada por D-pad), não usam o IME nativo do Tizen. `SendInputString`
  é aceito pela TV sem erro (a pílula "Enviado" aparece), mas o texto não chega a lugar nenhum —
  não existe campo de sistema focado pra injetar. Não dá pra contornar pelo protocolo público; fora
  do escopo desta spec investigar um caminho alternativo (ex. simular toques na grade on-screen).
- Suporte garantido a emoji/acentos — ⚠️ ainda não testado especificamente; o texto ASCII simples
  confirmado funciona no campo nativo. Não implementa fallback de transliteração.
- Autocomplete/sugestões — é só repasse de texto, a TV decide o resto.
- Senhas (a API tem um fluxo REST separado pra isso, `rest_ime_input`, fora do escopo aqui).

## Experiência

Mockups em FigCraft, arquivo "SamsungRemote", página "0004 — Teclado / envio de texto" (4 frames:
rodapé com o botão, overlay vazio, overlay com texto enviado, overlay com falha de envio).

### Botão "Teclado" na fileira Fonte/Menu/Informações

**Redesenhado em 2026-10-20** (FigCraft, mesma página) depois do teste na TV real: não fica mais
no rodapé junto com os tiles de app — tirar o teclado de perto de Netflix/YouTube/Prime Video fazia
parecer que funcionava neles, e não funciona (ver "Fora do escopo"). Virou um 4º botão **circular**
na fileira de cima (`KeyButton(.source)`, `.menu`, `.info`), mesmo tamanho/gradiente/sombra dos
vizinhos — não depende de favoritos de app, não compete visualmente com eles. Ícone `SF Symbol:
keyboard`, sem rótulo abaixo (como os outros três botões dessa fileira). Implementação:
`KeyboardToggleButton`/`KeyboardKeyCapStyle` em `UI/Components/TextKeyboardOverlay.swift` — não é
um `KeyButton` porque a ação é local (abrir/fechar o overlay), não uma `RemoteKey` pra TV.

### Overlay de digitação

Toque cobre o controle **inteiro** (da mesma largura/altura do `RemoteView`, por cima de tudo —
D-pad, botões de mídia, rodapé) com um fundo quase opaco (scrim preto ~95-99%). Não é um popover
pequeno: foco total no texto, sem campo em caixinha. Conteúdo, de cima pra baixo:

1. Ícone de teclado + rótulo "TECLADO DA TV" (maiúsculas, pequeno, cor de destaque).
2. O texto digitado em fonte grande (24pt), centralizado — funciona como o próprio campo de texto
   (não é só uma prévia ao lado de um `TextField` separado). Vazio mostra o placeholder "Comece a
   digitar…" esmaecido.
3. Um traço fino embaixo do texto (divisor com glow), e uma dica pequena abaixo dele.
4. Depois de **Enter**, uma pílula de status aparece: verde "Enviado · pode digitar de novo" se deu
   certo, vermelha "Falha ao enviar · TV desconectada" se a TV estava offline. Some assim que o
   usuário volta a editar o texto.
5. No rodapé do overlay: dois "keycaps" (`Enter` → "envia", ou "tenta" se a última tentativa falhou;
   `Esc` → "fecha") e uma nota de protocolo ("Esc fecha o teclado e envia `SendInputEnd`", ou, em
   erro, "overlay não trava: dá pra reenviar ou fechar").
6. O botão "Teclado" continua visível por cima do scrim, no canto superior direito (mesma posição
   da fileira Fonte/Menu/Informações), agora em estado "ativo" (gradiente azul, borda e glow de
   `Theme.accent`) — funciona como botão de fechar, junto com **Esc**.

Cores: estado neutro usa o azul de destaque do app (`Theme.accent`) no ícone/rótulo/divisor/glow;
ao falhar o envio, esses mesmos elementos trocam pra vermelho (`Theme.error`, novo token). O texto
digitado continua visível e editável nos dois casos — nada é perdido, **Enter** sempre tenta
reenviar o conteúdo atual do campo.

**Enter** com texto não-vazio: codifica UTF-8 → Base64 e manda `SendInputString` (ver protocolo
abaixo); texto permanece no campo (não limpa, não fecha o overlay) — repetir **Enter** reenvia o
mesmo texto (reflete o estado de erro: "tenta"). Texto vazio: **Enter** não faz nada.

**Esc** (ou tocar de novo no botão "Teclado", já ativo): fecha o overlay e manda `SendInputEnd`.

Falha de envio (WebSocket caiu): não fecha o overlay nem limpa o texto — só troca a cor de destaque
pra vermelho e mostra a pílula de erro; o usuário decide se tenta de novo (**Enter**) ou fecha
(**Esc**/botão).

## Protocolo / dados

Documentado em `docs/protocol/samsung-tizen-remote.md` §3 ("Envio de texto (`SendInputString`)"),
✅ **validado na AU8000 real** (2026-10-20), com a ressalva de escopo confirmada (ver "Fora do
escopo"): só funciona em campos nativos do Tizen, não em apps de streaming de terceiros.

```json
{
  "method": "ms.remote.control",
  "params": {
    "Cmd": "<base64(texto em UTF-8)>",
    "DataOfCmd": "base64",
    "TypeOfRemote": "SendInputString"
  }
}
```

Pra fechar o teclado da TV:

```json
{"method": "ms.remote.control", "params": {"TypeOfRemote": "SendInputEnd"}}
```

- Nada é persistido (sem histórico de texto enviado, sem favoritos — é um campo efêmero).
- Implementação: nova função em `Core/TV/TVProtocol.swift` (ex. `RemoteMessage.text(_:)` e
  `RemoteMessage.textEnd()`), no mesmo estilo de `RemoteMessage.key(_:action:)`. Envio pelo
  `TVWebSocketClient.send(_:)` já existente — não precisa de cliente novo.
- O broadcast `custom.remote.textReceived` **não foi necessário** na AU8000 — confirmado funcionando
  sem ele no campo nativo testado (Smart Hub).

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Botão "Teclado" na fileira Fonte/Menu/Informações do `RemoteView`, visível e habilitado quando conectado (independente de favoritos de app). |
| FR-2 | Toque cobre o controle inteiro com o overlay de digitação; texto grande centralizado, foco automático. |
| FR-3 | `Enter` com texto não-vazio codifica UTF-8→Base64 e manda `SendInputString`; texto permanece no campo; `Enter` com texto vazio não manda nada. |
| FR-4 | `Esc`, ou tocar de novo no botão "Teclado" (ativo), fecha o overlay e manda `SendInputEnd`. |
| FR-5 | Falha de envio mostra a pílula de erro dentro do overlay (vermelho), sem fechar nem limpar o texto — `Enter` tenta de novo. |
| FR-6 | Nada do texto digitado é persistido em disco ou log; overlay sempre abre vazio. |

## Critérios de aceite

- [x] Automatizado: `RemoteMessage.text("Olá 👋")` gera exatamente o JSON documentado acima, com
      `Cmd` em Base64 de UTF-8 (fixture comparando bytes, não só "não lança exceção");
      `RemoteMessage.textEnd()` gera o payload de `SendInputEnd`; string vazia não gera mensagem
      (tratado na UI/model, não na codificação). `ProtocolTests.textPayload`/`textEndPayload`,
      `scripts/dev.sh test` passando.
- [x] Manual na TV (2026-10-20): testado na busca nativa do Smart Hub — texto chega certo, pílula
      "Enviado" aparece, sem precisar do broadcast `custom.remote.textReceived`. Testado também em
      YouTube e Prime Video — a TV aceita o envio (pílula "Enviado", sem erro) mas o texto não
      aparece em lugar nenhum: confirmado que esses apps não usam o IME nativo (ver "Fora do
      escopo"). **Não testado**: acentuação/emoji no campo nativo, comportamento de `SendInputEnd`,
      substituir-vs-concatenar em envios repetidos — ficam como questões em aberto, não bloqueiam o
      status `Implemented` porque o caminho principal (campo nativo) já está confirmado funcionando.

## Plano de testes

**Automatizado** (`SamsungRemoteTests/`): encoding UTF-8→Base64 de `RemoteMessage.text(_:)` contra
fixtures (ASCII puro, acentos, emoji, string vazia tratada fora da camada de protocolo);
`RemoteMessage.textEnd()` contra o payload fixo de `SendInputEnd`.

**Manual na TV** (`docs/tv/UN65AU8000GXZD.md`): ✅ feito em 2026-10-20. Confirmado funcionando na
busca nativa do Smart Hub (texto chega certo, sem precisar do broadcast). Confirmado **não
funcionando** em YouTube e Prime Video (a TV aceita o envio sem erro, mas o texto não chega a lugar
nenhum — esses apps não usam o IME nativo do Tizen, ver "Fora do escopo"). Resultado documentado
aqui e em `docs/protocol/samsung-tizen-remote.md` §3 em vez de voltar a spec pra `Draft`, porque o
caminho principal (campo nativo) está confirmado funcionando — a limitação em apps de streaming é
um achado de plataforma, não um defeito do protocolo/implementação.

## Questões em aberto

- ⚠️ `Cmd` substitui o conteúdo do campo ou concatena a cada chamada? Testado só com um envio por
  vez até agora — não confirmado o comportamento de dois envios seguidos sem fechar o overlay.
- ⚠️ `SendInputEnd` é necessário/fecha o teclado virtual mesmo, ou a TV já fecha sozinha ao perder
  foco? Ainda sem confirmação — não testado especificamente.
- ✅ **Resolvido**: o broadcast `custom.remote.textReceived` **não é necessário** na AU8000 —
  confirmado funcionando sem ele no campo nativo testado.
- ⚠️ Acentuação e emoji funcionam de fato no campo nativo da TV, ou só ASCII? Só texto simples foi
  testado até agora.
- ✅ **Resolvido (negativo)**: `SendInputString` **não funciona em apps de streaming de terceiros**
  (YouTube, Prime Video confirmados; Netflix não testado, mesmo padrão esperado) — eles renderizam
  o próprio teclado virtual, sem usar o IME nativo do Tizen. Não há correção possível pelo protocolo
  público; documentado como limitação permanente em "Fora do escopo", não como bug a resolver.
- Detecção automática de foco via `ms.remote.imeStart`/`ms.remote.imeEnd` (fora do escopo aqui) —
  ⚠️ ainda não testado se esses eventos também disparam quando o "teclado" é só a UI interna de um
  app de streaming; se não dispararem nesse caso, dá pra usar isso pra **detectar automaticamente**
  se o teclado do app vai funcionar ali e avisar o usuário antes de ele tentar digitar. Candidato a
  spec futura.
