(function () {
  if (window.__PFT_APP_INITIALIZED__) return;
  window.__PFT_APP_INITIALIZED__ = true;

  // Resolve the assets base URL robustly (works even when document.currentScript is null)
  function getAssetsBase() {
    // Prefer an explicit hint on the script tag
    const scriptWithHint = document.querySelector('script[data-pft-base]');
    if (scriptWithHint && scriptWithHint.src) {
      const hinted = scriptWithHint.getAttribute('data-pft-base') || '.';
      return new URL(hinted, scriptWithHint.src).href;
    }
    // Fallback: find this script by filename
    const byName = Array.from(document.scripts).find(s => (s.src || '').endsWith('/assets/pfts/pfts.js'));
    if (byName && byName.src) {
      return new URL('./', byName.src).href; // folder containing pfts.js
    }
    // Last resort: relative to page URL (works for local previews)
    return new URL('assets/pfts/', window.location.href).href;
  }

  const ASSETS_BASE = getAssetsBase(); // e.g. .../assets/pfts/

  function h(tag, attrs, ...children) {
    const el = document.createElement(tag);
    if (attrs) for (const [k, v] of Object.entries(attrs)) {
      if (k === "class") el.className = v;
      else if (k === "html") el.innerHTML = v;
      else el.setAttribute(k, v);
    }
    for (const c of children) {
      if (c == null) continue;
      el.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    }
    return el;
  }

  function mount(container, data) {
    const byPhenology = {1: "Evergreen", 2: "Deciduous", 3: "Grass"};
    const names = Object.keys(data).sort();

    const select = h("select", { id: "pft-select", "aria-label": "Select PFT" });
    for (const name of names) select.appendChild(h("option", { value: name }, name));

    const phenEl = h("span", { id: "pft-phenology", style: "opacity:.8" });
    const table  = h("table", { class: "pft-table", id: "pft-params" });
    const mapImg = h("img", { id: "pft-map", class: "pft-map", alt: "Selected PFT distribution map" });

    const ui = h("div", { class: "pft-ui" },
      h("div", { class: "pft-controls pft-card" },
        h("label", { for: "pft-select" }, h("strong", null, "PFT")),
        select,
        phenEl
      ),
      h("div", { class: "pft-row" },
        h("div", { class: "pft-card" },
          h("h3", { style: "margin-top:0" }, "Parameters"),
          table
        ),
        h("div", { class: "pft-card" },
          h("h3", { style: "margin-top:0" }, "Distribution map"),
          mapImg,
          h("div", { style: "opacity:.8; font-size:.9em; margin-top:.4rem" },
            "Map images are generated from potential non-zero NPP."
          )
        )
      )
    );

    function renderParams(obj) {
      table.innerHTML = "";
      const entries = Object.entries(obj.parameters || {});
      if (!entries.length) {
        table.appendChild(h("tr", null, h("td", null, "(no parameters found)")));
        return;
      }
      for (const [k, v] of entries) {
        table.appendChild(
          h("tr", null,
            h("th", null, k),
            h("td", null, typeof v === "object" ? JSON.stringify(v) : String(v))
          )
        );
      }
    }

    function update(name) {
      const d = data[name];
      if (!d) return;
      renderParams(d);
      const phen = byPhenology[d.phenology] || String(d.phenology);
      phenEl.textContent = `Phenology: ${phen}`;

      // Optional map (hide gracefully if missing)
      const url = new URL(`maps/${encodeURIComponent(name)}.png`, ASSETS_BASE).href;
      mapImg.style.display = "";
      mapImg.src = url;
      mapImg.alt = `${name} distribution map`;
      mapImg.onerror = () => { mapImg.style.display = "none"; };
    }

    select.addEventListener("change", () => update(select.value));
    container.innerHTML = "";
    container.appendChild(ui);

    if (names.length) {
      select.value = names[0];
      update(names[0]);
    }
  }

  async function init() {
    const container = document.getElementById("pft-app");
    if (!container) return;
    try {
      const jsonURL = new URL("pfts.json", ASSETS_BASE).href;
      const res = await fetch(jsonURL);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      mount(container, data);
    } catch (err) {
      container.innerHTML = `<div class="pft-card">Failed to load PFT data (${String(err)}).</div>`;
      console.error("PFT app error:", err);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
