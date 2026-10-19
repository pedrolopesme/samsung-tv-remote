# ADR 0004 — Entitlement `network.server` para descoberta SSDP

**Status:** Accepted · 2026-10-19

## Contexto

A spec 0003 (descoberta automática) manda um M-SEARCH SSDP via UDP multicast
(`239.255.255.250:1900`) e espera respostas unicast de volta. O protocolo em si já foi validado
fora do sandbox (script Python contra a AU8000 real, ver `docs/specs/0003-descoberta-automatica.md`).

Rodando o app empacotado (sandbox + `network.client` apenas), a busca não encontra nada — a TV e
o Mac estão confirmados na mesma rede (usuário confirmou), mas zero TVs aparecem na lista.

**Hipótese:** `com.apple.security.network.client` cobre o padrão "conecta num destino X, recebe
resposta de X" (REST, WebSocket — já usados no app). SSDP é diferente: manda pro grupo multicast,
mas cada dispositivo responde do **próprio IP individual**, não do endereço multicast. Esse padrão
"manda pra A, recebe de B/C/D" provavelmente não é coberto por `network.client` — o App Sandbox
filtra o tráfego de entrada por não bater com o fluxo que o app "iniciou" no sentido estrito.

## Decisão

Adicionar `com.apple.security.network.server` ao `Config/SamsungRemote.entitlements`, **só**
pra viabilizar receber as respostas SSDP. Nenhuma outra mudança de comportamento — o app continua
sem nenhum listener de verdade (não abre porta nenhuma pra ser acessado de fora), é estritamente
pra permitir que o socket UDP já existente (`SSDPDiscovery`) receba os datagramas de resposta.

## Consequências

- Entitlement adicional no bundle — tecnicamente amplia a superfície de rede permitida pelo
  sandbox (de "só cliente" pra "cliente + servidor"), mesmo o app nunca abrindo um serviço de
  verdade. É o preço de usar um protocolo de descoberta (UDP, resposta de peer arbitrário) dentro
  do sandbox.
- ✅ **Confirmado**: rebuild com a entitlement + teste manual do app empacotado na rede real —
  a TV passou a aparecer na busca. Resolveu de fato, não ficou só na hipótese.
- Nenhum dado sai do Mac além do já esperado (M-SEARCH multicast + leitura das respostas); não
  abre a app pra receber conexões não solicitadas de fora da busca SSDP que ela mesma inicia.
