# Spec 0003 — Descoberta automática

| | |
|---|---|
| **Status** | Implemented (protocolo + entitlement `network.server` validados contra a AU8000 real) |
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

**SSDP (UPnP discovery)**, porta UDP 1900, multicast `239.255.255.250`. **Validado contra a AU8000
real** (`192.168.68.109`, 2026-10-19, script Python descartável — não representa o código final).

Envio (M-SEARCH):
```
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX: 2
ST: upnp:rootdevice
```

⚠️ **O `ST` do roadmap (`urn:samsung.com:device:RemoteControlReceiver:1`) não funciona** — testado
5x, zero respostas. `ST: ssdp:all` funciona mas é ruidoso (9+ linhas só da TV). `ST:
upnp:rootdevice` é o equilíbrio certo: testado 5x, 5/5 a TV respondeu, 1 linha por serviço.

Resposta real da TV pra `upnp:rootdevice` (chegam **3 respostas do mesmo IP**, não 1):
```
HTTP/1.1 200 OK
LOCATION: http://192.168.68.109:7678/nservice/
SERVER: Samsung-Linux/4.1, UPnP/1.0, Samsung_UPnP_SDK/1.0
ST: upnp:rootdevice
USN: uuid:827c17fe-2309-4b24-a117-38cb94ae3fa3::upnp:rootdevice
```
```
HTTP/1.1 200 OK
LOCATION: http://192.168.68.109:9197/dmr
SERVER: Samsung-Linux/4.1, UPnP/1.0, Samsung_UPnP_SDK/1.0
ST: upnp:rootdevice
USN: uuid:2ba8b004-b48f-4628-a77f-9f1733d8a2b6::upnp:rootdevice
```
```
HTTP/1.1 200 OK
LOCATION: http://192.168.68.109:9080
SERVER: Linux/4.1.10, UPnP/1.0, Portable SDK for UPnP devices
X-User-Agent: NRDP MDX
ST: upnp:rootdevice
USN: uuid:SSTV-NL21-...::upnp:rootdevice
```

A 3ª é o serviço MDX do Netflix rodando na própria TV (SDK de 2ª tela), não a Samsung — `SERVER`
não contém "samsung", filtro já exclui corretamente. As duas primeiras **são as duas Samsung de
verdade, no mesmo IP, em portas diferentes** (`7678` = serviço principal Tizen, `9197` =
MediaRenderer/DLNA). Isso importa pra deduplicação:

- Filtra por `SERVER` contendo "samsung" (case-insensitive) — único critério necessário, testado.
- **Deduplica por host (IP), nunca por host+porta** — a mesma TV manda ≥2 respostas Samsung
  válidas em portas diferentes; sem isso, uma TV só apareceria como "2 TVs encontradas" (bug).
  Mantém a porta da primeira resposta Samsung de cada IP, só pra exibir "UPnP :`porta`" na lista.
- O IP vem do host da URL em `LOCATION` — não precisa buscar o XML do dispositivo, só a URL já
  basta. A validação de "é mesmo uma Samsung TV" quem faz é o fluxo existente
  (`TVInfoClient.fetch`/`setUp(host:)`, spec 0001) — SSDP só sugere o candidato.
- Implementação: `SSDPDiscovery` em `Core/TV/`, socket BSD cru (`socket`, `sendto` multicast,
  `recvfrom` com timeout via `SO_RCVTIMEO`), parsing de texto HTTP-like simples (só separar
  `header: valor` por linha, sem parser HTTP completo). Mesmo estilo de `WakeOnLAN.swift` — sem
  `Network.framework`, sem dependência externa (ADR 0001).
- Timeout: `MX: 2` no pedido + margem de rede → ~3 s de espera total antes de considerar "nada
  encontrado" (consistente com o timeout de 2 s já usado no health-check REST, spec 0001).

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Ao abrir `SetupView`, disparar a busca SSDP (`ST: upnp:rootdevice`) numa task separada, sem bloquear a tela. |
| FR-2 | Filtrar respostas por `SERVER` contendo "samsung"; deduplicar por host (IP); extrair IP+porta do `LOCATION`. |
| FR-3 | Exatamente 1 TV encontrada → preencher o campo de IP (editável, não autoconecta). |
| FR-4 | Mais de 1 TV encontrada → listar pra escolher; tocar preenche o campo. |
| FR-5 | Nenhuma encontrada em ~3 s → nada muda na tela, sem mensagem de erro. |
| FR-6 | Falha de socket/rede na busca não trava nem atrasa o resto do onboarding. |

## Critérios de aceite

- [x] Automatizado: parsing de uma resposta SSDP válida (fixture) extrai IP+porta certos; resposta
      sem "samsung" no `SERVER` é ignorada; resposta malformada/sem `LOCATION` não derruba o
      parser; duas respostas Samsung do mesmo IP em portas diferentes deduplicam pra 1 candidato.
- [x] Manual na TV: `SetupView` encontra a AU8000 de verdade (app empacotado, sandbox) e preenche
      o IP sozinho — **confirmado pelo usuário, 2026-10-19**. Standby/sem-TV ainda não testados.

## Plano de testes

**Automatizado** (`SamsungRemoteTests/`): fixtures com as 3 respostas reais capturadas acima
(2 Samsung em portas diferentes + 1 Netflix/MDX a ignorar); extração de IP+porta; dedup por host.

**Manual na TV** (`docs/tv/UN65AU8000GXZD.md`): o protocolo já foi validado por script (ver
"Protocolo / dados") — falta confirmar que o **app empacotado e com sandbox** consegue enviar/
receber multicast igual ao script fez (⚠️ entitlement, ver "Questões em aberto"); testar com a TV
ligada e em standby.

## Questões em aberto

- ✅ **Resolvido**: a entitlement `com.apple.security.network.server` era mesmo necessária —
  confirmado rodando o app empacotado de verdade (ver ADR 0004). Sem ela, zero TVs encontradas
  mesmo com TV e Mac na mesma rede; com ela, funciona.
- SSDP funciona com a TV em standby/"rede em espera"? Ainda não testado (só testado com a TV
  ligada) — mesma incerteza já marcada no health-check REST (spec 0001).
