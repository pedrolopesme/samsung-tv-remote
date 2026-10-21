# Protocolo: controle remoto de TVs Samsung Tizen (2016+)

> A API é **não oficial**: a Samsung não a documenta publicamente para terceiros.
> O conteúdo abaixo vem do comportamento observado e consolidado por projetos abertos
> (ex.: `samsungtvws` em Python e a integração `samsungtv` do Home Assistant).
> Itens marcados com ⚠️ precisam ser validados na TV de referência (`docs/tv/UN65AU8000GXZD.md`).

## Visão geral

| Canal | Porta | Uso |
|---|---|---|
| REST `http://<ip>:8001/api/v2/` | 8001 | Informações do aparelho, estado de energia, MAC |
| WebSocket `wss://<ip>:8002/api/v2/channels/samsung.remote.control` | 8002 | Envio de teclas e eventos de app |
| Wake-on-LAN (UDP broadcast) | 9 | Ligar a TV a partir do standby |

A porta 8001 também aceita WebSocket sem TLS, mas modelos 2018+ exigem a 8002 com token.
**O app usa só a 8002.**

## 1. REST — informações do aparelho

`GET http://<ip>:8001/api/v2/` → JSON. Campos que o app usa:

| Campo | Exemplo | Uso |
|---|---|---|
| `device.modelName` | `UN65AU8000GXZD` | Exibição |
| `device.name` | `[TV] Samsung AU8000 65` | Nome (o app remove `[TV] `) |
| `device.PowerState` | `on` / `standby` | Decidir entre conectar e mandar Wake-on-LAN |
| `device.wifiMac` | `80:47:86:..` | MAC para Wake-on-LAN (mesmo em rede cabeada) ⚠️ |
| `device.TokenAuthSupport` | `"true"` | Confirma que a TV usa token |

- Se a TV está em standby com "rede em espera" ativa, o REST pode responder com `PowerState: standby`. ⚠️
- Timeout curto (1–2 s) serve de *health check* antes de abrir o WebSocket.
- Fixture de exemplo: `SamsungRemoteTests/ProtocolTests.swift` (`Fixtures.au8000Info`).

## 2. WebSocket — conexão e pareamento

```
wss://<ip>:8002/api/v2/channels/samsung.remote.control?name=<base64(nome)>[&token=<token>]
```

- `name`: nome do cliente em Base64. Aparece no pop-up da TV. **O token fica associado a esse nome.**
- O certificado TLS é **autoassinado**. O cliente aceita esse certificado só para o IP da TV.
- Primeira conexão (sem token): a TV mostra "Permitir este dispositivo?". A resposta chega como evento.

### Eventos recebidos

| `event` | Significado | Ação do app |
|---|---|---|
| `ms.channel.connect` | Conectado. `data.token` traz o token (na 1ª vez ou se mudou) | Salvar token no Keychain e liberar envio |
| `ms.channel.unauthorized` | Usuário negou ou o cliente está bloqueado | Mostrar erro e orientar a liberar na TV |
| `ms.channel.timeOut` | O pop-up expirou sem resposta | Pedir para tentar de novo |
| `ms.channel.clientConnect` / `clientDisconnect` | Outros clientes | Ignorar |
| `ed.installedApp.get` | Resposta à lista de apps (ver §5) | Futuro (spec 0002) |
| `ms.remote.imeStart` | A TV focou um campo de texto (teclado virtual abriu) | Futuro (spec 0004) ⚠️ |
| `ms.remote.imeEnd` | A TV desfocou/fechou o campo de texto | Futuro (spec 0004) ⚠️ |

Exemplo de `ms.channel.connect`:

```json
{"event":"ms.channel.connect","data":{"clients":[...],"id":"...","token":"12345678"}}
```

Liberar ou bloquear clientes na TV: **Configurações › Geral › Gerenciador de dispositivos externos ›
Gerenciador de conexão de dispositivos › Lista de dispositivos**. ⚠️ (os nomes dos menus variam por firmware)

### Manutenção da conexão

- A TV pode fechar conexões ociosas. O app manda **ping a cada 20 s** e, se o envio falhar,
  **reconecta uma vez e reenvia** a tecla.
- Com a TV ligada, `KEY_POWER` a coloca em standby e a conexão cai logo depois.

## 3. Envio de teclas

```json
{
  "method": "ms.remote.control",
  "params": {
    "Cmd": "Click",
    "DataOfCmd": "KEY_VOLUP",
    "Option": "false",
    "TypeOfRemote": "SendRemoteKey"
  }
}
```

- `Cmd`: `Click` (toque), `Press` (segura) e `Release` (solta). O app usa `Click` com repetição
  local (450 ms de atraso e depois a cada 140 ms) para volume e canal.
- Implementação: `RemoteMessage.key(_:action:)` em `Core/TV/TVProtocol.swift`.

### Teclas

| Grupo | Códigos |
|---|---|
| Energia | `KEY_POWER` (alterna), `KEY_POWEROFF` ⚠️ |
| Sistema | `KEY_HOME`, `KEY_RETURN` (voltar), `KEY_EXIT`, `KEY_MENU`, `KEY_SOURCE`, `KEY_INFO`, `KEY_GUIDE`, `KEY_TOOLS` |
| Navegação | `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT`, `KEY_ENTER` |
| Áudio | `KEY_VOLUP`, `KEY_VOLDOWN`, `KEY_MUTE` |
| Canais | `KEY_CHUP`, `KEY_CHDOWN`, `KEY_PRECH`, `KEY_CH_LIST` |
| Mídia | `KEY_PLAY`, `KEY_PAUSE`, `KEY_STOP`, `KEY_REWIND`, `KEY_FF`, `KEY_REC` |
| Números | `KEY_0` … `KEY_9` |
| Cores | `KEY_RED`, `KEY_GREEN`, `KEY_YELLOW`, `KEY_CYAN` |

O app implementa o subconjunto em `RemoteKey`. Ao adicionar uma tecla, atualize esta tabela.

### Envio de texto (`SendInputString`) ✅ validado na AU8000 real, com ressalva importante

```json
{
  "method": "ms.remote.control",
  "params": {
    "Cmd": "PGFzZTY0KHRleHRvKQ==",
    "DataOfCmd": "base64",
    "TypeOfRemote": "SendInputString"
  }
}
```

- `Cmd`: o texto inteiro do campo, em **Base64 de UTF-8**. `DataOfCmd` é sempre a string fixa
  `"base64"` (não confundir com o `DataOfCmd` de `SendRemoteKey`, que ali carrega o código da tecla).
- **Só funciona em campos nativos do Tizen** (ex. busca do Smart Hub) — **confirmado** na AU8000 real,
  2026-10-20: o texto chega certo, sem precisar de nenhum broadcast antes.
- **Não funciona em apps de streaming de terceiros** (YouTube, Prime Video — **confirmado** na AU8000
  real, 2026-10-20): o envio não dá erro (a TV aceita a mensagem no WebSocket normalmente), mas o
  texto não aparece em lugar nenhum. Esses apps renderizam o próprio teclado virtual dentro da UI do
  app (grade de botões navegada por D-pad), **não usam o IME nativo do Tizen** — não existe campo de
  sistema focado pra `SendInputString` injetar, então a TV simplesmente descarta a mensagem. Não é um
  problema de formato/protocolo: é limitação de arquitetura de cada app, inerente à plataforma.
  Netflix não foi testado, mas o mesmo padrão é esperado (apps de streaming costumam implementar
  teclado próprio).
- O broadcast `{"method":"ms.channel.emit","params":{"event":"custom.remote.textReceived","to":"broadcast"}}`,
  que algumas TVs exigem segundo `samsungtvws` antes do primeiro envio, **não é necessário na AU8000**
  — confirmado: funcionou sem ele no campo nativo.
- Pra fechar o teclado virtual da TV: `{"method":"ms.remote.control","params":{"TypeOfRemote":"SendInputEnd"}}`.
  ⚠️ Ainda não testado se isso fecha o teclado de fato ou se a TV já fecha sozinha ao perder foco.
- A TV sinaliza quando um campo de texto nativo está focado pelos eventos `ms.remote.imeStart` /
  `ms.remote.imeEnd` (ver §2) — ⚠️ ainda não confirmado se esses eventos também disparam (ou não)
  quando o "teclado" é só a UI interna de um app de streaming; seria um jeito de distinguir os dois
  casos automaticamente, mas não foi testado.
- ⚠️ Acentuação e emoji no campo nativo: ainda não testado especificamente (só texto ASCII simples
  confirmado funcionando até agora).
- Fonte do formato original: `samsungtvws` (`remote.py`, classes `SendInputString`/`SendInputEnd`).
  Validação de comportamento na TV real: `docs/specs/0004-teclado-envio-texto.md`.

## 4. Wake-on-LAN

- Com a TV desligada (standby), o WebSocket não responde. Para ligar, mande um **magic packet**:
  6 bytes `0xFF` + 16 repetições do MAC (102 bytes), por UDP broadcast `255.255.255.255:9`.
- Requisito na TV: **Configurações › Geral › Rede › Configurações avançadas › Ligar com dispositivo móvel**
  ativado. ⚠️
- Depois do WoL, o app consulta o REST a cada 1 s (por até ~20 s) até `PowerState == on` e então conecta.
- Implementação: `Core/TV/WakeOnLAN.swift` (socket BSD com `SO_BROADCAST`).
- macOS 15+: o broadcast exige a permissão de **Rede Local** (`NSLocalNetworkUsageDescription`).

## 5. Apps (fora do MVP)

Pelo WebSocket:

```json
{"method":"ms.channel.emit","params":{"event":"ed.installedApp.get","to":"host"}}
{"method":"ms.channel.emit","params":{"event":"ed.apps.launch","to":"host",
  "data":{"appId":"<id>","action_type":"DEEP_LINK"}}}
```

Ou pelo REST: `POST http://<ip>:8001/api/v2/applications/<appId>` ⚠️ (alguns firmwares 2021+ retornam 404).
Os IDs dos apps (Netflix, YouTube, Globoplay…) devem ser **lidos da própria TV** com `ed.installedApp.get`,
não fixados no código. Ver `docs/roadmap.md`.

## 6. Modelos não suportados

| Linha | Protocolo | Suporte |
|---|---|---|
| C/D/E/F (≤2013) | Socket legado porta 55000 | ❌ |
| H/J (2014–2015) | Pareamento criptografado (PIN) porta 8080 | ❌ |
| K+ (2016–2017) | WebSocket 8001 | ⚠️ não testado |
| 2018+ (incl. AU8000 2021) | WebSocket 8002 + token | ✅ alvo |
