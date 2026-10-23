(() => {
  "use strict";

  /* ---------------- Menu mobile ---------------- */
  const burger = document.getElementById("navBurger");
  const mobileNav = document.getElementById("navMobile");
  if (burger && mobileNav) {
    burger.addEventListener("click", () => {
      const open = burger.getAttribute("aria-expanded") === "true";
      burger.setAttribute("aria-expanded", String(!open));
      mobileNav.classList.toggle("is-open", !open);
    });
    mobileNav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        burger.setAttribute("aria-expanded", "false");
        mobileNav.classList.remove("is-open");
      });
    });
  }

  /* ---------------- Vídeo do hero: fundo full-bleed (desktop) ou palco
     (mobile) ----------------
   * Só um dos dois é baixado, de acordo com o breakpoint no load (o `src`
   * não vem no HTML pra evitar baixar os dois). Toca uma vez e termina
   * parado no frame final (sem loop, por design). Com prefers-reduced-motion
   * não toca: fica só no poster/primeiro frame. */
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const isDesktop = window.matchMedia("(min-width: 880px)").matches;
  const activeVideo = isDesktop
    ? document.querySelector(".hero__bg-video")
    : document.querySelector(".stage__video");
  const activeSrc = isDesktop ? "assets/hero-bg.mp4" : "assets/hero-montagem.mp4";

  if (activeVideo) {
    activeVideo.src = activeSrc;
    if (!reduceMotion) {
      activeVideo.play().catch(() => {
        /* autoplay bloqueado pelo navegador — fica no poster/primeiro frame */
      });
    }
  }

  /* ---------------- Link de download (release mais recente) ----------------
   * Busca o asset .dmg da última release no GitHub e aponta os
   * botões "Baixar" pra ele direto. Se a API falhar (rate limit,
   * offline), mantém o href padrão apontando pra página de releases. */
  const REPO = "pedrolopesme/samsung-tv-remote";
  const downloadButtons = document.querySelectorAll("[data-download-cta]");
  const metaEl = document.querySelector("[data-download-meta]");

  fetch(`https://api.github.com/repos/${REPO}/releases/latest`)
    .then((res) => (res.ok ? res.json() : Promise.reject(res.status)))
    .then((release) => {
      const asset = (release.assets || []).find((a) => a.name.endsWith(".dmg"));
      if (!asset) return;

      downloadButtons.forEach((btn) => {
        btn.href = asset.browser_download_url;
      });

      if (metaEl) {
        const mb = (asset.size / (1024 * 1024)).toFixed(1).replace(".", ",");
        metaEl.textContent =
          `${release.tag_name} · ${mb} MB · macOS 14 ou superior · Apple Silicon e Intel`;
      }
    })
    .catch(() => {
      /* mantém os links padrão (página de releases) */
    });
})();
