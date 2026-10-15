# Spec 0001 — Controle remoto MVP

| | |
|---|---|
| **Status** | Accepted (implementação inicial feita, falta validar na TV) |
| **Autor** | Pedro |
| **Criada** | 2026-10-14 |
| **TV alvo** | UN65AU8000GXZD (ver `docs/tv/UN65AU8000GXZD.md`) |

## Contexto

Quero controlar a TV Samsung da sala pelo Mac sem pegar o controle físico, com um app nativo,
rápido, bonito e que funcione pelo teclado.

## Objetivos

1. App de **menu bar** que abre um controle remoto visual com um clique.
2. **Parear** com a TV por IP e lembrar o pareamento (sem pop-up nas próximas vezes).
3. Enviar as teclas essenciais com latência percebida < 150 ms na rede local.
4. **Ligar** a TV desligada (Wake-on-LAN) e desligar (`KEY_POWER`).
5. Usar pelo **teclado** com o controle aberto.

## Fora do escopo (ver `docs/roadmap.md`)

- Descoberta automática da TV (SSDP/mDNS). No MVP o IP é digitado.
- Atalhos para abrir apps (Netflix, YouTube, Globoplay).
- Teclado virtual / envio de texto.
- Atalhos globais (fora do popover) e teclas de mídia do Mac.
- Múltiplas TVs.
- SmartThings / cloud.

## Experiência

### Primeiro uso

1. O usuário clica no ícone de controle no menu bar e vê "Conecte sua TV" com um campo de IP.
2. Ao clicar em **Conectar**, o app consulta `GET :8001/api/v2/`.
   - Se não responder: "A TV não respondeu. Ela está ligada e na mesma rede?"
   - Se responder: salva nome, modelo e MAC e abre o WebSocket.
3. Se o handshake demorar mais de 1,2 s, o status vira **"Aceite na TV"** e aparece um banner.
4. O usuário aceita na TV → o token vai para o Keychain → o controle aparece com o status "Conectado".

### Uso diário

- O popover abre → o app conecta sozinho (checa o REST, depois o WebSocket com token).
- Ao tocar em uma tecla sem conexão, o app conecta antes e envia em seguida.
- Ao tocar em energia:
  - Conectado → `KEY_POWER` (TV vai para standby).
  - Desconectado → Wake-on-LAN, polling no REST até `on` (máx. ~20 s) e conexão.

### Layout (de cima para baixo)

1. Cabeçalho: nome da TV, indicador de status (ponto colorido + texto) e **energia** (vermelho).
2. Linha: Fonte · Menu · Info.
3. **D-pad** circular com OK central (azul).
4. Linha: Voltar · Início · Sair.
5. Balancim **VOL** · Mudo / Guia · Balancim **CH**. Os balancins repetem enquanto pressionados.
6. Mídia: ⏪ ▶︎ ⏸ ⏩.
7. Rodapé: mensagem de erro (se houver), ⚙︎ Preferências, Reconectar, Sair.

Visual: corpo grafite com gradiente, teclas com relevo e sombra que "afunda" ao pressionar,
haptic no trackpad a cada toque. Sempre em modo escuro. Largura de 288 pt.

### Preferências (⌘,)

IP, MAC (Wake-on-LAN), modelo, status; botões **Salvar**, **Parear novamente** e **Esquecer TV**;
tabela de atalhos.

### Atalhos de teclado (com o controle aberto)

| Tecla | Ação |
|---|---|
| ← ↑ → ↓ | Navegação |
| ⏎ | OK |
| ⌫ | Voltar |
| H | Início |
| + / = e − | Volume (repete ao segurar) |
| M | Mudo |
| [ / ] | Canal − / + |
| Espaço | Play |
| P | Pause |
| 0–9 | Números |

## Estados

```
notConfigured ──setUp(ip)──▶ connecting ──(>1,2 s)──▶ awaitingApproval
                                 │                         │
                                 ├──── connect ok ◀────────┘
                                 ▼
 disconnected ◀──falha/queda── connected ──KEY_POWER──▶ (queda) ▶ disconnected
      │
      └──power──▶ waking ──REST "on"──▶ connecting
```

`errorMessage` é independente do estado e é limpo a cada nova tentativa.

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Validar o IP via REST antes de abrir o WebSocket (timeout de 2 s). |
| FR-2 | Conectar em `wss://<ip>:8002/...` com `name` em Base64 e `token` quando houver. |
| FR-3 | Aceitar o certificado autoassinado **somente** para o host configurado. |
| FR-4 | Guardar o token no Keychain, por TV (chave = IP). |
| FR-5 | Tratar `ms.channel.connect`, `ms.channel.unauthorized` e `ms.channel.timeOut`. |
| FR-6 | Enviar teclas como `ms.remote.control` / `Click`; repetir volume e canal enquanto pressionados. |
| FR-7 | Ping a cada 20 s; em falha de envio, reconectar uma vez e reenviar. |
| FR-8 | Wake-on-LAN para o MAC salvo; polling no REST até `PowerState == on`. |
| FR-9 | Configuração (IP, MAC, nome, modelo) persistida no UserDefaults do sandbox. |
| FR-10 | Atalhos de teclado conforme a tabela acima. |

## Requisitos não funcionais

- macOS 14+, Swift 5, sem dependências externas, sandbox + `network.client`.
- Nenhum dado da TV real (token, MAC, SN) no repositório.
- Inicialização do popover < 100 ms; nada bloqueia a main thread.

## Critérios de aceite

- [ ] Projeto compila no Xcode 16 com `scripts/dev.sh build` (ainda não compilado: o código foi escrito fora de um Mac).
- [ ] Testes unitários de protocolo, WoL e storage passando (`scripts/dev.sh test`).
- [ ] Pareamento completo na AU8000 com pop-up e token salvo.
- [ ] Reabrir o app conecta **sem** novo pop-up.
- [ ] Todas as teclas do layout funcionam na AU8000.
- [ ] Volume repete enquanto segura o balancim.
- [ ] Energia desliga (conectado) e liga via WoL (standby).
- [ ] Atalhos de teclado funcionam com o popover em foco.
- [ ] Mensagens de erro aparecem nos cenários: IP errado, TV desligada sem MAC, permissão negada, pop-up expirado.

## Plano de testes

**Automatizado** (`SamsungRemoteTests/`): payload JSON das teclas, URL do WebSocket,
parsing de eventos, decodificação do `/api/v2/`, magic packet e normalização de MAC,
ida e volta da configuração.

**Manual na TV:** checklist em `docs/tv/UN65AU8000GXZD.md`.

## Questões em aberto

- O `device.wifiMac` funciona para WoL quando a TV está no cabo? (provavelmente não, e aí é preciso preencher o MAC à mão)
- A AU8000 responde ao REST em standby ou fica muda? Isso define o texto do erro.
- Ad-hoc signing + Keychain: cada rebuild pode pedir "Permitir acesso" ao Keychain. Se incomodar, ver ADR 0002.
