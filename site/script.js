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

  /* ---------------- Animação de montagem (palco) ----------------
   * As peças começam "espalhadas" (pre-animate) e se encaixam
   * (settled) quando o palco entra na viewport. Sem suporte a
   * IntersectionObserver ou com prefers-reduced-motion, mostra
   * direto o estado final (sem classe pre-animate). */
  const assembly = document.getElementById("assembly");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (assembly && !reduceMotion && "IntersectionObserver" in window) {
    assembly.classList.add("pre-animate");
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            assembly.classList.remove("pre-animate");
            assembly.classList.add("settled");
            observer.disconnect();
          }
        });
      },
      { threshold: 0.35 }
    );
    observer.observe(assembly);
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
