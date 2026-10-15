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
