# Spec 0003 — Descoberta automática

| | |
|---|---|
| **Status** | Accepted (mockups revisados no FigCraft; protocolo SSDP ainda não validado na TV real) |
| **Autor** | Pedro |
| **Criada** | 2026-10-16 |
| **Depende de** | 0001 |

## Contexto

Hoje o primeiro uso (`SetupView`) exige digitar o IP da TV à mão — o usuário precisa ir em
Configurações › Geral › Rede › Status da rede na própria TV pra achar esse número. SSDP
(UPnP discovery, UDP multicast) permite achar a TV na rede local sem isso.

Zero dependências (ADR 0001): implementar à mão com socket BSD, no mesmo estilo de
`WakeOnLAN.swift` — envia multicast, mas aqui também precisa **receber** respostas, o que é novo.

## Objetivos

1. Ao abrir `SetupView`, procurar TVs Samsung na rede local via SSDP, em paralelo com o campo de
   IP manual (não bloqueia a tela).
2. Se achar exatamente uma, sugerir/preencher o campo de IP automaticamente (continua editável).
3. Se achar mais de uma, listar pra escolher.
4. Se não achar nenhuma, não mostrar erro — o campo manual continua funcionando exatamente como
   hoje. Descoberta é um atalho, nunca um requisito.

## Fora do escopo

- Seletor persistente de múltiplas TVs já pareadas (isso é o item 0007 do roadmap — "Múltiplas
  TVs" — feature separada; aqui é só a lista de candidatas no onboarding, descartada depois de
  escolher).
- mDNS/Bonjour — Tizen não anuncia por aí de forma confiável (já descartado numa exploração
  anterior).
- Descoberta com a TV desligada — ⚠️ ver "Questões em aberto", mesma incerteza que já existe pro
  health-check REST com a TV em standby.

## Experiência

Mockups em FigCraft, arquivo "SamsungRemote", página "0003 — Descoberta automática" (4 frames).

### `SetupView` — 4 estados da mesma tela

**1 · Buscando (0–3 s) — FR-1/FR-6**
Campo de IP vazio (placeholder `192.168.0.50`), igual hoje. Abaixo dele, um spinner pequeno +
"Procurando TVs na rede…" (texto secundário). Botão "Conectar" desabilitado (campo vazio) — regra
já existente, inalterada. Campo e botão seguem usáveis o tempo todo; falha de socket só apaga o
spinner sem avisar nada.

**2 · Exatamente 1 TV — FR-3**
Campo preenchido com o IP do `LOCATION`, borda em accent (mostra que veio da descoberta, não foi
digitado). Abaixo, ✓ verde + "TV encontrada na rede · IP preenchido". Botão "Conectar" habilitado
(campo não-vazio, regra existente). O destaque (borda accent + texto verde) desaparece assim que o
usuário edita o campo manualmente — nunca conecta sozinho.

**3 · Várias TVs — FR-4**
Campo continua vazio (ambíguo demais pra preencher sozinho). Abaixo, "`N` TVs Samsung encontradas
· clique para usar". Lista com uma linha por TV: IP em negrito + "Samsung · UPnP :`porta`" em
texto secundário (porta vem do `LOCATION` de cada resposta). Hover numa linha revela um rótulo
"usar" à direita. Tocar preenche o campo com aquele IP e remove a lista — a tela passa a parecer o
estado 2. Lista é descartada ao sair da tela (nada persiste — isso é o roadmap 0007).

**4 · Nada encontrado (~3 s) — FR-5**
Spinner some, tela volta a ficar idêntica à de hoje: sem lista, sem texto, sem erro. Standby,
firewall ou rede sem suporte a multicast são resultados esperados, não falhas.

## Protocolo / dados

**SSDP (UPnP discovery)**, porta UDP 1900, multicast `239.255.255.250`.

Envio (M-SEARCH):
```
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: 2
ST: urn:samsung.com:device:RemoteControlReceiver:1
```

Resposta esperada (texto HTTP-like sobre UDP, várias podem chegar de dispositivos diferentes na
rede — roteador, outras smart TVs, impressoras etc.):
```
HTTP/1.1 200 OK
LOCATION: http://<ip-da-tv>:9197/dmr
SERVER: ...Samsung...
ST: urn:samsung.com:device:RemoteControlReceiver:1
USN: ...
```

- Filtra respostas por `ST` (bate com o que foi enviado) e/ou `SERVER` contendo "samsung" —
  várias coisas na rede respondem SSDP, a maioria não é a TV.
- O IP (e a porta, pra mostrar "UPnP :`porta`" na lista quando há mais de uma TV) vêm do host/porta
  da URL em `LOCATION` — não precisa buscar o XML de descrição do dispositivo
  (`http://<ip>:9197/dmr`), só a URL já basta. A validação de "é mesmo uma Samsung TV" quem faz é o
  fluxo existente (`TVInfoClient.fetch`/`setUp(host:)`, spec 0001) — SSDP só sugere o candidato.
- Implementação nova: `SSDPDiscovery` (ou similar) em `Core/TV/`, socket BSD cru (`socket`,
  `sendto` multicast, `recvfrom` com timeout), parsing de texto HTTP-like simples (não precisa de
  parser HTTP completo, só separar `header: valor` por linha). Mesmo estilo de `WakeOnLAN.swift`
  (sem `Network.framework`, sem dependência externa).
- Timeout: `MX: 2` no pedido + margem de rede → ~3 s de espera total antes de considerar "nada
  encontrado" (consistente com o timeout de 2 s já usado no health-check REST, spec 0001).

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Ao abrir `SetupView`, disparar a busca SSDP numa task separada, sem bloquear a tela. |
| FR-2 | Filtrar respostas por `ST`/`SERVER` da Samsung; extrair o IP do `LOCATION`. |
| FR-3 | Exatamente 1 TV encontrada → preencher o campo de IP (editável, não autoconecta). |
| FR-4 | Mais de 1 TV encontrada → listar pra escolher; tocar preenche o campo. |
| FR-5 | Nenhuma encontrada em ~3 s → nada muda na tela, sem mensagem de erro. |
| FR-6 | Falha de socket/rede na busca não trava nem atrasa o resto do onboarding. |

## Critérios de aceite

- [ ] Automatizado: parsing de uma resposta SSDP válida (fixture) extrai o IP certo; respostas de
      outros dispositivos (sem o `ST`/`SERVER` esperado) são ignoradas; resposta malformada não
      derruba o parser.
- [ ] Manual na TV: `SetupView` encontra a AU8000 de verdade na rede e preenche o IP sozinho;
      comportamento com a TV em standby; comportamento numa rede sem a TV (nada quebra).

## Plano de testes

**Automatizado** (`SamsungRemoteTests/`): fixture de resposta SSDP válida da Samsung + fixtures de
respostas de outros dispositivos (devem ser ignoradas) + resposta malformada (não deve lançar
erro); extração do IP a partir do `LOCATION`.

**Manual na TV** (`docs/tv/UN65AU8000GXZD.md`): confirmar que a AU8000 responde ao `ST`
`urn:samsung.com:device:RemoteControlReceiver:1` (⚠️ nunca testado — ver "Questões em aberto");
testar com a TV ligada e em standby; testar numa rede com mais de uma Samsung TV, se possível.

## Questões em aberto

- ⚠️ Essa TV responde de fato ao `ST` `urn:samsung.com:device:RemoteControlReceiver:1`? Esse
  valor veio só do roadmap, nunca foi validado — mesma categoria de suposição que já se provou
  falsa antes (`ed.installedApp.get`, spec 0002). Se não responder, o plano B é mandar `ST:
  ssdp:all` (mais genérico, qualquer dispositivo UPnP responde) e filtrar depois pelo `SERVER`
  header ou pelo conteúdo do XML em `LOCATION`.
- ⚠️ Receber respostas de multicast UDP dentro do App Sandbox pode exigir a entitlement
  `com.apple.security.network.server` além da já existente `network.client`. Só descobre
  testando o build real; se precisar, vira ADR próprio (AGENTS.md exige justificar qualquer
  entitlement nova).
- SSDP funciona com a TV em standby/"rede em espera"? Provável que não — mesma incerteza já
  marcada no health-check REST (spec 0001) — mas nunca testado especificamente para SSDP.
