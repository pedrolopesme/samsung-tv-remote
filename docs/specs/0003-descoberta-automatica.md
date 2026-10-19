# Spec 0003 — Descoberta automática

| | |
|---|---|
| **Status** | Draft |
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

### `SetupView`

- Ao aparecer a tela, dispara a busca SSDP automaticamente, sem bloquear nada — o campo de IP e
  o botão "Conectar" continuam utilizáveis desde o primeiro frame.
- Timeout curto (~3 s, ver "Protocolo / dados"). Se nada responder nesse tempo, a tela não muda:
  fica exatamente como é hoje, só com o campo de IP vazio pra digitar.
- Achou exatamente 1 TV: preenche o campo de IP com o valor encontrado (usuário ainda pode
  apagar/editar antes de clicar Conectar — nunca conecta sozinho sem o usuário confirmar).
- Achou mais de 1: mostra uma lista curta abaixo do campo ("TVs encontradas: Sala • Quarto"),
  tocar numa preenche o campo com aquele IP.
- Nenhum texto de erro por "não achou nada" — isso é esperado e comum (TV em standby, rede sem
  suporte a multicast, firewall etc.), não é uma falha do app.

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
- O IP da TV vem do host da URL em `LOCATION` — não precisa buscar o XML de descrição do
  dispositivo (`http://<ip>:9197/dmr`), só o IP já basta pra alimentar o `TVInfoClient.fetch`/
  `setUp(host:)` que já existe (spec 0001) — a validação de "é mesmo uma Samsung TV" quem faz é
  esse fluxo, SSDP só sugere o IP.
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
