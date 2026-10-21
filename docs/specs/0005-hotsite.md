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
  storyboard detalhado (peças, rastros, guias) amarrado ao scroll; a implementação usa o
  vídeo real da montagem (`hero-montagem.mp4`, 1680×900, H.264 comprimido a ~956 KB), que
  toca uma vez e para no último frame (sem loop, por decisão de design).

## Experiência

Mockups em FigCraft, arquivo "SamsungRemote", página "Hotsite — one-page (proposta)" (2
frames: `Hotsite · 1440` desktop, `Hotsite · 390` mobile — mesmo conteúdo, pilha de uma
coluna no mobile).

Seções, nessa ordem: nav (logo + links + "Baixar", menu hambúrguer no mobile) → hero (H1 +
CTAs + "palco" com o vídeo da montagem do controle) → anatomia (as 4 peças do controle,
com os screenshots reais do app) → grade de 6 recursos → screenshot da janela de
Preferências → 3 passos de instalação + callout do IP → faixa de download → FAQ (4
perguntas) → rodapé.

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
- `site/script.js` — menu mobile (toggle de classe), respeito a `prefers-reduced-motion`
  no vídeo do palco (não toca quando o usuário prefere menos movimento), e o fetch de
  release acima.
- `site/assets/` — o vídeo do hero (`hero-montagem.mp4`, 1680×900, H.264, ~956 KB após
  compressão) e 3 screenshots reais do app (mesmos de `docs/screenshots/`,
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
| FR-2 | Hero com H1, CTAs ("Baixar para macOS" / "Ver no GitHub") e o "palco" com o vídeo da montagem das 4 peças do controle (toca uma vez, para no último frame). |
| FR-3 | Botões de download apontam pro `.dmg` da release mais recente via GitHub API; fallback gracioso pra página de releases se a API falhar. |
| FR-4 | Layout responsivo: um HTML/CSS só, breakpoint em 880px reproduzindo os dois estados do mockup (não dois sites separados). |
| FR-5 | Screenshots reais do app (não ilustrações) nas seções "Anatomia" e "Ajustes". |
| FR-6 | Publicado via GitHub Actions pro GitHub Pages a cada push em `main` que toque `site/`. |

## Critérios de aceite

- [x] Automatizado: não aplicável (sem lógica testável — site estático de conteúdo).
- [x] Manual: verificado num browser real (Chrome DevTools, `python3 -m http.server`
      local) nos dois breakpoints (390 e 1440) — nav, menu mobile (abre/fecha), vídeo do
      palco (toca uma vez e para no último frame), fetch de release (populou
      `v0.3.0 · 1,6 MB · ...` e os links de download com o `.dmg` real), screenshots reais
      carregando corretamente, sem overlaps ou cortes em nenhuma seção.
- [ ] Manual: GitHub Pages publicado de verdade e acessível em
      `https://pedrolopesme.github.io/samsung-tv-remote/` — depende de habilitar Pages
      nas configurações do repositório (Settings › Pages › Source: GitHub Actions),
      passo único que não dá pra fazer só com código.

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

## Questões em aberto

- Habilitar GitHub Pages (Settings › Pages › Source: GitHub Actions) é um passo manual
  nas configurações do repositório — fora do alcance de um PR de código.
- O hero usa o vídeo real da montagem, uma vez, parando no último frame; a versão
  scroll-scrubbing completa do mockup continua fora de escopo (ver "Fora do escopo") e
  seria uma spec futura.
