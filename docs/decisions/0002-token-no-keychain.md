# ADR 0002 — Token de pareamento no Keychain

**Status:** Accepted · 2026-10-14

## Contexto
A TV devolve um token em `ms.channel.connect`. Com o token, ela não pede permissão de novo.
Quem tem o token consegue controlar a TV pela rede local, então ele é um segredo, ainda que de baixo risco.

## Decisão
- Token em item genérico do Keychain (`service = com.pedrolopesme.SamsungRemote.pairing-token`,
  `account = <ip da TV>`), atrás do protocolo `TokenStore`.
- IP, MAC, nome e modelo no `UserDefaults` (não são segredos).
- `InMemoryTokenStore` para testes.

## Consequências
- Com assinatura ad-hoc ("Sign to Run Locally"), cada rebuild muda a assinatura e o macOS pode
  perguntar "SamsungRemote quer acessar o item do Keychain". Clicar em "Sempre permitir" resolve até o próximo build.
  Se isso atrapalhar o desenvolvimento, as alternativas são: (a) configurar um Development Team local
  (fora do repo, via `xcconfig` ignorado) ou (b) um `TokenStore` de debug em UserDefaults, só em `#if DEBUG`.
- O token está ligado ao IP: se o IP da TV mudar, é preciso parear de novo. Reserve o IP no DHCP.
