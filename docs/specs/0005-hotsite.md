# Spec 0005 — Hotsite

| | |
|---|---|
| **Status** | Implemented |
| **Autor** | Pedro |
| **Criada** | 2026-10-21 |
| **Depende de** | — |

## Contexto

O projeto não tinha um endereço público — só o repositório no GitHub. Um site estático
de uma página (one-page), hospedado via GitHub Pages no próprio repositório, serve como
cartão de visita: explica o que o app faz, mostra screenshots reais e linka o download
direto do `.dmg`.

## Objetivos

1. Site estático (HTML/CSS/JS puro, sem build step, sem dependências — mesmo espírito do
   ADR 0001) servido via GitHub Pages, associado ao repositório como endereço do projeto.
2. Fiel ao design do FigCraft (arquivo "SamsungRemote", página "Hotsite — one-page
   (proposta)"): duas versões de referência no mockup — desktop (`Hotsite · 1440`) e
   mobile (`Hotsite · 390`) — implementadas como **um** HTML/CSS responsivo (não dois
   arquivos), com breakpoint único em 880px reproduzindo os dois estados do mockup.
3. Link de download sempre aponta pro `.dmg` da release mais recente de verdade (via
   GitHub API, client-side), não um valor fixo que fica desatualizado a cada release.
4. Usa os screenshots reais do app (os mesmos de `docs/screenshots/`), não ilustrações
   genéricas.

## Fora do escopo

- Build step (bundler, framework, CSS preprocessor) — HTML/CSS/JS direto, igual ao resto
  do projeto não ter dependências externas.
- Analytics/telemetria de visitas — contradiria o próprio discurso do site ("sem
  telemetria").
- CMS ou conteúdo editável sem tocar código — é um site de projeto pessoal, editar o HTML
  é suficiente.
- Animação de scroll-scrubbing da "montagem em camadas" do hero — o mockup mostra um
  storyboard detalhado (peças, rastros, guias) amarrado ao scroll; a implementação usa
  vídeo real em vez de CSS/JS, um por breakpoint (paisagem no desktop, retrato no
  mobile), ambos tocando uma vez e parando no último frame (sem loop, por decisão de
  design).
- Vídeo de fundo em resolução de produção definitiva — o FigCraft documenta o canvas
  desktop em 1440×900 com exports em 2560×1600 (Retina); os assets atuais (`hero-bg.mp4`
  1440×900 e `hero-bg-mobile.mp4` 540×1080, ambos comprimidos) são as versões mais
  recentes enviadas pelo design, mas podem ser trocados por versões de resolução maior
  sem mudar nada no código (mesmo nome de arquivo).

## Experiência

Mockups em FigCraft, arquivo "SamsungRemote", página "Hotsite — one-page (proposta)" (2
frames: `Hotsite · 1440` desktop, `Hotsite · 390` mobile — mesmo conteúdo, pilha de uma
coluna no mobile). O hero do desktop ganhou uma segunda iteração depois do mockup
inicial, documentada como anotação de texto no próprio arquivo FigCraft (nós "Spec ·
..." na página do hotsite: título, intro, canvas, zona de texto, zona de movimento,
frame final e fallback).

Seções, nessa ordem: nav (logo + links + "Baixar", menu hambúrguer no mobile) → hero →
anatomia (as 4 peças do controle, com os screenshots reais do app) → grade de 6 recursos
→ screenshot da janela de Preferências → 3 passos de instalação + callout do IP → faixa
de download → FAQ (4 perguntas) → rodapé.

**Hero, desktop (≥880px)**: vídeo full-bleed cobrindo o viewport inicial inteiro
(`object-fit: cover`, sem card/moldura) — o movimento acontece no fundo, a página só
sobrepõe nav e texto. A nav flutua por cima (já era `sticky` + `backdrop-filter: blur`
com fundo semitransparente; o hero sobe atrás dela via
`margin-top: calc(-1 * var(--nav-h))`, o vídeo some por trás da faixa translúcida). Zona
de texto à esquerda (H1 + sub + CTAs + meta) com um scrim em gradiente horizontal
(`rgba(5,7,10,.95) → 0`, esquerda pra direita) garantindo contraste; "role para ver os
recursos ↓" no canto inferior esquerdo. O vídeo mostra as 4 camadas coloridas se
montando, virando o controle e deslizando até aparecer dentro de um Mac (barra de menus
e popover do app), parando nesse frame final sem loop.

**Hero, mobile (<880px)**: sem mockup do FigCraft pra esse tratamento (o frame
`Hotsite · 390` não foi redesenhado) — extensão direta do mesmo padrão full-bleed do
desktop, motivada por um vídeo retrato enviado depois (`hero-bg-mobile.mp4`, 540×1080;
o "palco" em card da iteração anterior foi removido, já não fazia sentido pra um vídeo
vertical). Mesmo mecanismo (vídeo + scrim + nav flutuando via margin negativo), mas:

- Scrim vertical (não horizontal): `rgba(5,7,10,.95)` no topo, esmaecendo até quase
  transparente perto do fim — o vídeo mobile concentra o "controle revelado" na parte de
  baixo do frame, não à direita como no desktop.
- Texto centralizado (como já era), não em coluna à esquerda.
- Altura do hero (`height: 100svh`, não `min-height`) calculada a partir de uma medição
  real do vídeo: o dispositivo/controle começa a aparecer a **64,8%** da altura do frame
  (medido pixel a pixel no poster — `scripts` ad-hoc, não parte do repo). Com
  `min-height: 100vh` ingênuo, o texto empurra o hero pra além do viewport, o vídeo
  estica junto e o controle sai da área visível (vídeo igual, mas o "momento" dele fica
  invisível sem rolar). `100svh` fixo resolve isso: o controle sempre aparece dentro do
  primeiro viewport, nos tamanhos de tela comuns.
- `@media (max-width: 879px) and (max-height: 720px)`: em telas baixas (iPhone SE e
  afins) o texto sozinho já ocupa proporção grande da tela — esconde a pílula "macOS ·
  vive na barra de menus" e reduz fontes pra abrir espaço suficiente antes do controle,
  evitando sobreposição.

Cores, tipografia (Inter) e todo o texto extraídos diretamente do arquivo `.figcraft`
(cores de `fills`/`strokes`, `font_size`/`font_style` de cada nó de texto) — não
aproximados visualmente.

## Protocolo / dados

Nada de rede do lado do servidor — é 100% estático. O único acesso externo é client-side:

```js
fetch(`https://api.github.com/repos/pedrolopesme/samsung-tv-remote/releases/latest`)
```

Usado pra apontar os botões "Baixar"/"Baixar para macOS"/"Baixar o .dmg" pro
`browser_download_url` do asset `.dmg` da release mais recente, e preencher a legenda
(`v0.3.0 · 1,6 MB · macOS 14 ou superior · Apple Silicon e Intel`) com dados reais em vez
de um valor fixo. Se a API falhar (rate limit, offline), os links caem pro fallback
`href` já presente no HTML (`/releases/latest`), e a legenda mantém o link estático pra
página de releases — nunca quebra, só perde o atalho direto.

- `site/index.html` — estrutura semântica, uma seção por bloco do mockup.
- `site/styles.css` — mobile-first; tokens de cor como custom properties; breakpoint
  desktop único em `@media (min-width: 880px)`.
- `site/script.js` — menu mobile (toggle de classe); um único `<video class="hero__bg-video">`
  pros dois breakpoints, `src` e `poster` escolhidos por `matchMedia("(min-width: 880px)")`
  (desktop baixa `hero-bg.mp4`/`hero-bg-poster.jpg`, mobile baixa
  `hero-bg-mobile.mp4`/`hero-bg-mobile-poster.jpg` — nunca os dois: nenhum dos dois vem
  no HTML), respeitando `prefers-reduced-motion` (não toca, fica só no poster/primeiro
  frame); e o fetch de release acima.
- `site/assets/` — dois vídeos do hero, H.264 comprimido (`libx264 -preset slow -crf
  23..26 -movflags +faststart`): `hero-bg.mp4` (desktop, 1440×900, CRF 26, ~1,3 MB) e
  `hero-bg-mobile.mp4` (mobile, 540×1080, CRF 26, ~261 KB), cada um com seu
  `hero-bg*-poster.jpg` (último frame, fallback pro `prefers-reduced-motion` e antes do
  vídeo carregar); e 3 screenshots reais do app (mesmos de `docs/screenshots/`,
  redimensionados pro tamanho de exibição), em PNG + WebP (`<picture>` com WebP
  primeiro).
- `.github/workflows/pages.yml` — publica `site/` no GitHub Pages a cada push em `main`
  que toque esse diretório, via `actions/upload-pages-artifact` +
  `actions/deploy-pages` (sem Jekyll — não processa os docs em Markdown do resto do
  repositório).

## Requisitos funcionais

| ID | Requisito |
|---|---|
| FR-1 | Nav com logo, links de âncora (`#recursos`, `#como-funciona`, `#perguntas`) e CTA "Baixar"; menu hambúrguer substitui os links no mobile. |
| FR-2 | Hero com H1, CTAs ("Baixar para macOS" / "Ver no GitHub") e vídeo real da montagem das 4 peças do controle, full-bleed atrás de nav e texto nos dois breakpoints (vídeo paisagem no desktop, retrato no mobile), tocando uma vez e parando no último frame. |
| FR-3 | Botões de download apontam pro `.dmg` da release mais recente via GitHub API; fallback gracioso pra página de releases se a API falhar. |
| FR-4 | Layout responsivo: um HTML/CSS só, breakpoint em 880px reproduzindo os dois estados do mockup (não dois sites separados). |
| FR-5 | Screenshots reais do app (não ilustrações) nas seções "Anatomia" e "Ajustes". |
| FR-6 | Publicado via GitHub Actions pro GitHub Pages a cada push em `main` que toque `site/`. |

## Critérios de aceite

- [x] Automatizado: não aplicável (sem lógica testável — site estático de conteúdo).
- [x] Manual: verificado num browser real (Chrome DevTools, `python3 -m http.server`
      local) em três alturas mobile (667, 784, 852) e desktop (1440) — nav, menu mobile
      (abre/fecha), vídeo do hero full-bleed nos dois breakpoints (toca uma vez e para
      no último frame; só um vídeo baixado por vez, confirmado via `currentSrc` do
      `<video>` ativo), controle do vídeo mobile visível no viewport inicial sem rolar e
      sem sobrepor o texto em nenhuma das três alturas testadas, fetch de release
      (populou `v0.3.0 · 1,6 MB · ...` e os links de download com o `.dmg` real),
      screenshots reais carregando corretamente, sem overlaps ou cortes em nenhuma seção.
- [x] Manual: GitHub Pages habilitado (via API, `build_type: workflow`, já que o passo
      "Settings › Pages › Source: GitHub Actions" também é exposto por
      `POST /repos/{owner}/{repo}/pages`) e publicado de verdade — verificado em
      `https://pedrolopesme.github.io/samsung-tv-remote/` (HTTP 200, vídeo do hero
      carregando do domínio real, console limpo).

## Plano de testes

**Manual (browser real)**: servido localmente, inspecionado via Chrome DevTools nos dois
breakpoint. Bugs reais encontrados e corrigidos ao longo do desenvolvimento (não
hipotéticos; 1 e 2 são da animação em CSS, uma iteração anterior depois substituída pelo
vídeo real):

1. `.stage__assembly` (`position: absolute`, todos os filhos também absolutos) colapsava
   pra largura 0 sem um `width` explícito — as "placas" da animação viravam linhas finas
   na cor da borda. Mesmo problema em `.anatomy__photos` como item de grid.
2. O JS nunca removia a classe `pre-animate` ao assentar a animação — o `transform`
   "espalhado" ficava preso para sempre, mesmo depois de `settled` ser adicionado.
3. Os atributos `width`/`height` dos `<img>` usavam os valores de **exibição** do mockup
   do Figma, não as dimensões reais dos arquivos redimensionados — causava overlap entre
   a pilha de screenshots e os cards abaixo no mobile.
4. `padding` de `.nav__mobile` não é limitado por `max-height: 0` — o painel "fechado"
   ainda mostrava uma fresta do primeiro link.
5. `img { max-width: 100% }` sem `height: auto` deixava o atributo `height` do HTML
   fixado enquanto o `max-width` encolhia a largura — as imagens saíam achatadas. Fix:
   `height: auto` global.
6. `min-height: 100vh` no hero mobile deixava o texto empurrar a altura real do hero
   pra além do viewport — o vídeo (absolute, inset:0) esticava junto, e como o "reveal"
   do controle fica perto do fim do vídeo (medido: 64,8% da altura), ele saía da área
   visível. Fix: `height: 100svh` fixo + espaçamento mais compacto, calculado a partir
   dessa medição pra garantir folga sem sobrepor.

## Questões em aberto

- O hero usa o vídeo real da montagem, uma vez, parando no último frame; a versão
  scroll-scrubbing completa do mockup continua fora de escopo (ver "Fora do escopo") e
  seria uma spec futura.
- O mobile ganhou o tratamento full-bleed sem mockup do FigCraft (ver "Experiência") —
  é uma extensão direta do padrão do desktop, não uma implementação de spec visual
  existente; se o design fizer um mockup formal depois, vale conferir contra essa
  implementação.
- A altura do hero mobile (`100svh` + espaçamento compacto) foi calibrada pra esse vídeo
  específico (reveal a 64,8% da altura); se o vídeo mudar de composição (reveal em outra
  posição), os números precisam ser recalculados.
- `hero-bg.mp4`/`hero-bg-mobile.mp4` são as versões mais recentes enviadas pelo design;
  o FigCraft também pede um export 2560×1600 pra Retina no desktop, que pode ser
  adicionado depois como uma segunda fonte (`<source media>`/`srcset`) sem mudar a
  estrutura.
