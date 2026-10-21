# Hotsite

Site estático de uma página — HTML/CSS/JS puro, sem build step, sem dependências (mesmo
espírito do ADR 0001 do app). Publicado via GitHub Pages a cada push em `main` que toque
esta pasta (`.github/workflows/pages.yml`).

Design: FigCraft, arquivo "SamsungRemote", página "Hotsite — one-page (proposta)".
Detalhes e critérios de aceite: `docs/specs/0005-hotsite.md`.

## Preview local

```bash
cd site
python3 -m http.server 8080
# http://localhost:8080
```

Sem servidor nenhum necessário além disso — é tudo arquivo estático.

## Estrutura

```
index.html   # uma seção por bloco do mockup
styles.css   # mobile-first; breakpoint desktop único em 880px
script.js    # menu mobile, animação de entrada do palco, link de download dinâmico
assets/      # screenshots reais do app (PNG + WebP)
```

## Link de download

Os botões "Baixar" buscam a release mais recente via GitHub API
(`api.github.com/repos/pedrolopesme/samsung-tv-remote/releases/latest`) e apontam pro
`.dmg` de verdade — não precisa editar o HTML a cada release nova. Se a API falhar, cai
pro fallback estático (`/releases/latest`).

## Habilitar o GitHub Pages (passo único, manual)

Settings › Pages › Source: **GitHub Actions**. Depois disso o workflow já publica
sozinho a cada push relevante em `main`.
