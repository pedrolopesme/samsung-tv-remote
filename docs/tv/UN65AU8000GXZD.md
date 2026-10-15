# TV de referência: Samsung UN65AU8000GXZD

| Campo | Valor |
|---|---|
| Modelo | UN65AU8000GXZD (Crystal UHD AU8000, 65") |
| Ano/linha | 2021 (código `T-NKLAUABC`, plataforma "Nikel" UHD) |
| Sistema | Tizen (geração 2021) |
| Firmware observado | `T-NKLAUABC-2301.1` |
| Região | Brasil (`BRA_DTV`) |
| Protocolo esperado | WebSocket **8002** + token (ver `docs/protocol/samsung-tizen-remote.md`) |

> **Privacidade:** número de série, DUID e MAC reais **não** ficam neste repositório.
> O app lê o MAC da própria TV (`GET /api/v2/` → `device.wifiMac`) e o guarda no UserDefaults.
> Se a TV estiver no cabo e o WoL não funcionar com o `wifiMac`, preencha à mão nas
> Preferências o MAC que aparece no menu de serviço/rede da TV (campo `MA`).

## Configurações necessárias na TV

Os nomes podem variar levemente entre firmwares. ⚠️ = a confirmar nesta TV.

1. **Pareamento:** na primeira conexão aceite "Permitir" no pop-up com o controle físico.
2. **Ligar pela rede:** Configurações › Geral › Rede › Configurações avançadas ›
   **Ligar com dispositivo móvel** = Ativado. ⚠️
3. **Notificação de acesso:** Configurações › Geral › Gerenciador de dispositivos externos ›
   Gerenciador de conexão de dispositivos › **Notificação de acesso** = "Apenas na primeira vez". ⚠️
4. **IP fixo (recomendado):** reserve o IP da TV no DHCP do roteador para o app não perder a TV.

## Checklist de validação manual (preencher ao testar)

| Item | Resultado | Data / firmware |
|---|---|---|
| `scripts/dev.sh tv-info <ip>` responde com `modelName` correto | ⬜ | |
| `PowerState` em standby aparece como `standby` (e não sem resposta) | ⬜ | |
| `device.wifiMac` serve para o WoL com a TV no cabo | ⬜ | |
| Pop-up de permissão aparece com o nome "Mac Remote" | ⬜ | |
| Token é devolvido em `ms.channel.connect` e reconexão não pede permissão | ⬜ | |
| Todas as teclas do MVP respondem (ver spec 0001 §Teclas) | ⬜ | |
| `KEY_POWER` com a TV ligada → standby | ⬜ | |
| Wake-on-LAN liga a TV em < 15 s | ⬜ | |
| Conexão sobrevive 10 min ociosa (ping) | ⬜ | |
