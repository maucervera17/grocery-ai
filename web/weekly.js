import {
  recommendWeekly,
  weeklyExport,
  measure,
  soldByWeight,
  qualifiersMatch,
} from "/weekly-plan.js";
import { parseMoney } from "/savings.js";
const money = (n) =>
  new Intl.NumberFormat("es-MX", { style: "currency", currency: "MXN" }).format(
    n / 100,
  );
const unitLabel = (unit) => ({ piece: "pieza", dozen: "docenas", package: "presentación" })[unit] || unit;
const quickQueries = { carne: ["Carne molida de res", "Bistec de res"], pollo: ["Pechuga de pollo sin hueso", "Pollo entero"] };
const esc = (v) =>
  String(v ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const suggestionHtml = (row) => {
  const options = quickQueries[row.name.toLowerCase()];
  return options && !row.offers.length
    ? `<div class="weekly-suggestions"><small>Prueba un tipo:</small>${options.map((q) => `<button type="button" data-suggest="${esc(row.id)}" data-suggest-query="${esc(q)}">${esc(q)}</button>`).join("")}</div>`
    : "";
};
const offerStatus = (row, pending) =>
  row.offers.length
    ? `${row.offers.length} ${row.offers.length === 1 ? "opción" : "opciones"}`
    : pending.has(row.id)
      ? "Buscando opciones…"
      : row.error
        ? "Revisa este producto"
        : "Sin opciones todavía";
const load = (k, f) => {
  try {
    return JSON.parse(localStorage.getItem(k)) ?? f;
  } catch {
    return f;
  }
};
export function mountWeekly({ root, search, location, onRegister }) {
  let state = load("barasu-weekly-v1", {
      id: crypto.randomUUID(),
      rows: [],
      travel: {},
      hourlyCents: 0,
      maxStores: 2,
      context: null,
    }),
    activePlan = null,
    pending = new Set(),
    batch = false,
    batchDone = 0,
    batchTotal = 0,
    autoSearchedSignature = null,
    autoRequested = false,
    activeRowId = state.rows?.[0]?.id ?? null;
  if (!Array.isArray(state.rows))
    state = {
      id: crypto.randomUUID(),
      rows: [],
      travel: {},
      hourlyCents: 0,
      maxStores: 2,
      context: null,
    };
  const persist = () =>
    localStorage.setItem("barasu-weekly-v1", JSON.stringify(state));
  const context = () => JSON.stringify(location());
  function invalidateLocation() {
    if (state.context !== context()) {
      state.context = context();
      state.travel = {};
      for (const row of state.rows) {
        row.offers = [];
        row.selected = null;
        row.approved = [];
      }
      activePlan = null;
      autoRequested = false;
      persist();
    }
  }
  function setDraft(items) {
    invalidateLocation();
    const changedDraft = items.length !== state.rows.length || items.some((item) => {
      const old = state.rows.find((row) => row.id === item.client_item_id);
      return !old || old.signature !== JSON.stringify([item.name, item.quantity, item.unit, item.notes]);
    });
    if (!changedDraft) return;
    autoRequested = false;
    state.rows = items.map((i) => {
      const old = state.rows.find((r) => r.id === i.client_item_id);
      const signature = JSON.stringify([i.name, i.quantity, i.unit, i.notes]);
      return old?.signature === signature
        ? old
        : {
            id: i.client_item_id,
            name: i.name,
            signature,
            query: [i.name, i.notes].filter(Boolean).join(" "),
            requested: i,
            offers: [],
            selected: null,
            approved: [],
            packages: 1,
            usualPriceCents: null,
          };
    });
    if (!state.rows.some((row) => row.id === activeRowId)) activeRowId = state.rows[0]?.id ?? null;
    for (const row of state.rows) {
      row.offers = row.offers.filter((o) =>
        qualifiersMatch(o.listing.productName, row.query),
      );
      if (
        row.selected &&
        !row.offers.some((o) => o.listing.productUrl === row.selected)
      ) {
        row.selected = null;
        row.approved = [];
        row.selectionSource = null;
      }
    }
    activePlan = null;
    persist();
    render();
  }
  function show() {
    invalidateLocation();
    render();
    if (autoRequested) optimize(false);
    root.scrollIntoView({ behavior: "smooth", block: "start" });
    const signature = JSON.stringify([state.context, state.rows.map((r) => [r.signature, r.query])]);
    if (!batch && state.rows.length && autoSearchedSignature !== signature) {
      autoSearchedSignature = signature;
      if (state.rows.some((r) => !r.offers.length)) void searchAll();
    }
  }
  async function find(id) {
    if (pending.has(id)) return;
    const row = state.rows.find((r) => r.id === id);
    if (!row) return;
    const query = (root.querySelector(`[data-query="${CSS.escape(id)}"]`)?.value ?? row.query).trim();
    if (!query) {
      row.error = "Escribe el producto o presentación que quieres buscar.";
      render();
      return;
    }
    if (query !== row.query) {
      row.offers = [];
      row.selected = null;
      row.approved = [];
      row.selectionSource = null;
      row.usualPriceCents = null;
      activePlan = null;
    }
    row.query = query;
    row.error = "";
    const requestContext = context();
    pending.add(id);
    render();
    try {
      const result = await search(query);
      if (row.query !== query || requestContext !== context() || !state.rows.includes(row)) return;
      row.error = result?.errors?.map((e) => e.message).join(" ") || "";
      if (result?.comparison?.data_mode === "live") {
        const previousSelection = row.selected;
        const previousSource = row.selectionSource;
        row.offers = result.comparison.offers;
        row.scope = result.comparison.scope;
        if (!row.offers.some((o) => o.listing.productUrl === previousSelection)) {
          row.selected = null;
          row.approved = [];
          row.selectionSource = null;
          row.usualPriceCents = null;
        } else {
          row.selected = previousSelection;
          row.selectionSource = previousSource;
          row.approved = [previousSelection];
        }
        activePlan = null;
        row.error = row.offers.length
          ? row.error
          : [result.reply, row.error].filter(Boolean).join(" ") ||
            "No hay ofertas. Prueba una presentación o marca específica.";
      } else {
        row.offers = [];
        row.selected = null;
        row.approved = [];
        row.selectionSource = null;
        row.error = result?.reply || "No se encontraron opciones. Prueba con un tipo, marca o presentación más específica.";
      }
    } catch {
      row.error = "La fuente tardó demasiado o no respondió. Puedes reintentar este producto.";
    } finally {
      pending.delete(id);
      if (batch) batchDone++;
      if (autoRequested) applyAutoSelection();
      persist();
      render();
    }
  }
  async function searchAll() {
    if (batch) return;
    const queue = state.rows.filter((row) =>
      !row.offers.length || row.offers.some((o) => Date.now() - Date.parse(o.listing.checkedAt) > 3600000),
    );
    if (!queue.length) return;
    batch = true;
    const batchSignature = JSON.stringify([state.context, state.rows.map((r) => [r.signature, r.query])]);
    batchDone = 0;
    batchTotal = queue.length;
    render();
    let next = 0;
    const worker = async () => {
      while (next < queue.length) await find(queue[next++].id);
    };
    try {
      await Promise.all(Array.from({ length: Math.min(2, queue.length) }, worker));
    } finally {
      batch = false;
      render();
      if (autoRequested) optimize(false);
      const currentSignature = JSON.stringify([state.context, state.rows.map((r) => [r.signature, r.query])]);
      if (currentSignature !== batchSignature && state.rows.some((r) => !r.offers.length)) {
        autoSearchedSignature = currentSignature;
        void searchAll();
      }
    }
  }
  function select(row, url) {
    const l = row.offers.find((o) => o.listing.productUrl === url)?.listing;
    if (!l) return;
    if (row.selected === url) {
      row.selected = null;
      row.approved = [];
      row.selectionSource = null;
      row.usualPriceCents = null;
      activePlan = null;
      persist();
      render();
      return;
    }
    row.selected = url;
    row.approved = [url];
    row.selectionSource = "manual";
    row.usualPriceCents = null;
    const wanted = measure(row.requested.quantity, row.requested.unit),
      pack = measure(l.quantity, l.unit);
    row.packages =
      wanted && pack && wanted.kind === pack.kind
        ? soldByWeight(l)
          ? Math.ceil((wanted.amount / pack.amount) * 1000 - 1e-9) / 1000
          : Math.ceil(wanted.amount / pack.amount - 1e-9)
        : 1;
    if (row.packages > 99) {
      row.selected = null;
      row.approved = [];
      row.error =
        "La cantidad requiere más de 99 unidades. Ajusta la cantidad de la lista antes de elegir.";
    }
    activePlan = null;
    persist();
    render();
  }
  function applyAutoSelection() {
    const recommendation = recommendWeekly(state.rows, { maxStores: state.maxStores });
    const selectedIds = new Set(recommendation.lines.map((line) => line.rowId));
    for (const row of state.rows) {
      if (row.selectionSource === "auto" && !selectedIds.has(row.id)) {
        row.selected = null;
        row.approved = [];
        row.selectionSource = null;
      }
    }
    for (const line of recommendation.lines) {
      const row = state.rows.find((r) => r.id === line.rowId);
      if (!row || (row.selected && row.selectionSource !== "auto")) continue;
      if (row.selected !== line.listing.productUrl) row.usualPriceCents = null;
      row.selected = line.listing.productUrl;
      row.approved = [line.listing.productUrl];
      row.selectionSource = "auto";
      row.packages = line.packages;
    }
    activePlan = null;
    persist();
    return recommendation;
  }
  function selectionReply(recommendation) {
    const chosen = recommendation.lines.length;
    const waiting = pending.size || batch;
    return `${chosen} de ${state.rows.length} productos elegidos en el editor${recommendation.stores.length ? ` en ${recommendation.stores.join(" y ")}` : ""}. Los planes de arriba pueden proponer alternativas distintas. ${recommendation.missing.length ? `Pendientes: ${recommendation.missing.join(", ")}.` : ""} ${waiting ? "Sigo buscando opciones; actualizaré la selección al recibirlas." : ""} Precio y existencias se confirman en cada tienda.`.trim();
  }
  function autoSelect() {
    if (!state.rows.length) return "Primero dime qué productos quieres agregar a tu lista.";
    invalidateLocation();
    autoRequested = true;
    const recommendation = applyAutoSelection();
    render();
    if (recommendation.lines.length) optimize(false);
    void searchAll();
    return selectionReply(recommendation);
  }
  function showSlide(index, scroll = false) {
    if (!state.rows.length) return;
    const next = Math.max(0, Math.min(index, state.rows.length - 1));
    activeRowId = state.rows[next].id;
    root.querySelectorAll("[data-week-panel]").forEach((panel, panelIndex) => {
      panel.hidden = panelIndex !== next;
    });
    root.querySelectorAll("[data-week-slide]").forEach((tab, tabIndex) => {
      tab.setAttribute("aria-selected", String(tabIndex === next));
      tab.tabIndex = tabIndex === next ? 0 : -1;
    });
    root.querySelector(".weekly-carousel-count").textContent = `Producto ${next + 1} de ${state.rows.length}`;
    root.querySelector("#week-prev").disabled = next === 0;
    root.querySelector("#week-next").disabled = next === state.rows.length - 1;
    if (scroll) root.querySelector(".weekly-carousel-nav").scrollIntoView({ behavior: "smooth", block: "start" });
  }
  function render() {
    root.hidden = false;
    const legacyUnspecified = state.rows.length >= 4 && state.rows.every((r) => r.requested.quantity === 1 && r.requested.unit === "piece");
    const activeIndex = Math.max(0, state.rows.findIndex((row) => row.id === activeRowId));
    const carouselStart = state.rows.length
      ? `<div class="weekly-carousel-nav" aria-label="Navegar productos"><span class="weekly-carousel-count" aria-live="polite">Producto ${activeIndex + 1} de ${state.rows.length}</span><div><button type="button" id="week-prev" aria-label="Producto anterior">‹</button><button type="button" id="week-next" aria-label="Producto siguiente">›</button></div></div><div class="weekly-carousel-tabs" role="tablist" aria-label="Productos de la lista">${state.rows.map((row, index) => `<button type="button" role="tab" id="week-tab-${esc(row.id)}" aria-controls="week-panel-${esc(row.id)}" data-week-slide="${index}">${esc(row.name)} <span aria-hidden="true">${row.selected ? "✓" : pending.has(row.id) ? "…" : row.offers.length ? "•" : "○"}</span></button>`).join("")}</div><div class="weekly-slides">`
      : "";
    root.innerHTML = `<section class="weekly"><div class="card-top"><h2>Mi súper semanal</h2><span>${state.rows.length} productos</span></div><p class="weekly-source-note">Comparamos la lista completa con precios publicados ${location()?.postal_code ? `para CP ${esc(location().postal_code)}` : "sin zona confirmada"}. Existencias y precio final se confirman en la tienda.</p><div class="weekly-toolbar"><button class="primary" id="week-auto-select" ${!state.rows.length ? "disabled" : ""}>Comparar mi súper</button><button class="secondary" id="week-search-all" ${batch || !state.rows.length ? "disabled" : ""}>${batch ? `Buscando ${batchDone}/${batchTotal}` : "↻ Actualizar"}</button></div><div id="week-results"></div><details class="weekly-guidance"><summary>Cómo funciona esta lista</summary><p>Barasu compara ofertas publicadas y conserva tus elecciones manuales. Puedes revisar marca, corte y presentación de cada producto abajo. Las existencias locales siguen sin confirmar.</p><button class="weekly-new secondary" id="week-new">Nueva semana · conservar productos</button></details>${
      !state.rows.length
        ? "<p>Escribe una lista: «Quiero huevos, pollo, carne y queso».</p>"
        : `${carouselStart}${state.rows
            .map(
              (r, index) =>
                `<article class="weekly-row" id="week-panel-${esc(r.id)}" role="tabpanel" aria-labelledby="week-tab-${esc(r.id)}" data-week-panel><div class="weekly-item-head"><span class="weekly-item-emoji" aria-hidden="true">${/queso|parmesano/i.test(r.name) ? "🧀" : /huevo/i.test(r.name) ? "🥚" : /pollo/i.test(r.name) ? "🍗" : /carne/i.test(r.name) ? "🥩" : /cereal/i.test(r.name) ? "🥣" : /lenteja/i.test(r.name) ? "🫘" : /arroz/i.test(r.name) ? "🍚" : /miel/i.test(r.name) ? "🍯" : /caf[eé]/i.test(r.name) ? "☕" : "🛒"}</span><div><h3>${index + 1}. ${esc(r.name)}</h3><small>${legacyUnspecified || r.requested.unit === "package" ? "Presentación por elegir" : `${esc(r.requested.quantity)} ${esc(unitLabel(r.requested.unit))}`} · ${offerStatus(r, pending)}</small></div></div><div class="weekly-query"><input data-query="${esc(r.id)}" aria-label="Buscar presentación de ${esc(r.name)}" value="${esc(r.query)}" placeholder="Ej. pechuga sin hueso, 1 kg"><button data-find="${esc(r.id)}" ${pending.has(r.id) ? "disabled" : ""}>${pending.has(r.id) ? "Buscando…" : r.offers.length ? "Buscar otra" : "Ver opciones"}</button></div>${suggestionHtml(r)}${/^(carne|pollo|queso)$/i.test(r.name) ? '<p class="comparison-help">Especifica el corte, tipo o marca para comparar productos que sí te sirven.</p>' : ""}${r.error ? `<p class="weekly-warning" role="status">${esc(r.error)}</p>` : ""}${
                  r.offers.length
                    ? `<div class="weekly-options">${r.offers
                        .map((o) => {
                          const l = o.listing,
                            selected = r.selected === l.productUrl;
                          return `<div class="weekly-offer ${selected ? "chosen" : ""}">${l.imageUrl ? `<img src="${esc(l.imageUrl)}" alt="${esc(l.productName)}" loading="lazy">` : '<span class="weekly-photo-fallback" aria-label="Sin foto disponible">🛒</span>'}<div><strong>${esc(l.productName)}</strong><small>${esc(l.retailer)} · ${money(l.priceCents)}<br>${money(o.basis === "piece" || o.basis === "package" ? o.unit_price_cents_per_100 / 100 : o.unit_price_cents_per_100)} / ${o.basis === "piece" ? "pieza" : o.basis === "package" ? "paquete" : "100 " + esc(o.basis)}</small><button data-choose="${esc(r.id)}" data-url="${esc(l.productUrl)}">${selected ? r.selectionSource === "auto" ? "✦ Barasu eligió" : "✓ Elegido" : "Elegir esta opción"}</button>${r.selected && !selected ? `<label class="approve"><input type="checkbox" data-approve="${esc(r.id)}" data-url="${esc(l.productUrl)}" ${r.approved.includes(l.productUrl) ? "checked" : ""}> También acepto esta alternativa</label>` : ""}</div></div>`;
                        })
                        .join(
                          "",
                        )}</div><small>${r.scope === "local" ? "Zona verificada al consultar" : "Precios publicados; existencias locales sin confirmar"} · ${esc(location()?.postal_code || "Sin CP")}</small>`
                    : ""
                }${r.selected ? `<div class="weekly-fields"><label>${soldByWeight(r.offers.find((o) => o.listing.productUrl === r.selected)?.listing) ? "Kilos (estimados)" : "Paquetes"}<input data-qty="${esc(r.id)}" type="number" min="0.001" step="0.001" max="99" value="${r.packages}"></label><label>Mi precio habitual / presentación o kg (MXN)<input data-usual="${esc(r.id)}" inputmode="decimal" placeholder="Sin referencia" value="${r.usualPriceCents === null ? "" : (r.usualPriceCents / 100).toFixed(2)}"></label></div><p class="comparison-help">La referencia corresponde al producto elegido. Aprobar alternativas expresa tu preferencia, no una certificación de calidad.</p>` : ""}</article>`,
            )
            .join("")}</div>`
    }<details class="weekly-preferences"><summary>Costo y conveniencia</summary><label>Tiendas para la selección del editor<select id="week-stores"><option value="1" ${state.maxStores === 1 ? "selected" : ""}>Una tienda</option><option value="2" ${state.maxStores === 2 ? "selected" : ""}>Hasta dos tiendas</option></select></label><label>Valor de una hora de tu tiempo (MXN)<input id="week-hour" inputmode="decimal" value="${state.hourlyCents / 100}"></label><p class="comparison-help">Opcional: indica el tiempo total de visita y traslado desde tu ubicación, y el costo de traslado o envío. Son estimaciones tuyas, no rutas medidas. Para dos tiendas sumamos las visitas por separado.</p>${[...new Set(state.rows.flatMap((r) => r.offers.map((o) => o.listing.retailer)))].map((s) => `<fieldset><legend>${esc(s)}</legend><label>Minutos por visita<input data-minutes="${esc(s)}" type="number" min="0" max="1440" value="${state.travel[s]?.minutes ?? ""}" placeholder="Sin estimación"></label><label>Traslado o envío (MXN)<input data-trip="${esc(s)}" inputmode="decimal" value="${state.travel[s]?.costCents == null ? "" : state.travel[s].costCents / 100}" placeholder="Sin estimación"></label><a href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(s + " cerca de " + (location()?.postal_code || "mí"))}" target="_blank" rel="noopener noreferrer">Buscar sucursal en mapas ↗</a></fieldset>`).join("")}</details><div id="week-error" role="status"></div></section>`;
    if (autoRequested) root.querySelector("#week-error").textContent = selectionReply(recommendWeekly(state.rows, { maxStores: state.maxStores }));
    if (state.rows.length) {
      showSlide(activeIndex);
      root.querySelector("#week-prev").onclick = () => showSlide(state.rows.findIndex((row) => row.id === activeRowId) - 1, true);
      root.querySelector("#week-next").onclick = () => showSlide(state.rows.findIndex((row) => row.id === activeRowId) + 1, true);
      root.querySelectorAll("[data-week-slide]").forEach((tab) => {
        tab.onclick = () => showSlide(Number(tab.dataset.weekSlide), true);
        tab.onkeydown = (event) => {
          if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
          event.preventDefault();
          const next = Math.max(0, Math.min(state.rows.length - 1, Number(tab.dataset.weekSlide) + (event.key === "ArrowRight" ? 1 : -1)));
          showSlide(next, true);
          root.querySelectorAll("[data-week-slide]")[next].focus();
        };
      });
      let touchStart = null;
      const slides = root.querySelector(".weekly-slides");
      slides.addEventListener("touchstart", (event) => { touchStart = [event.changedTouches[0].clientX, event.changedTouches[0].clientY]; }, { passive: true });
      slides.addEventListener("touchend", (event) => {
        if (!touchStart) return;
        const dx = event.changedTouches[0].clientX - touchStart[0];
        const dy = event.changedTouches[0].clientY - touchStart[1];
        touchStart = null;
        if (Math.abs(dx) > 55 && Math.abs(dx) > Math.abs(dy) * 1.4) showSlide(state.rows.findIndex((row) => row.id === activeRowId) + (dx < 0 ? 1 : -1), true);
      }, { passive: true });
    }
    root.querySelectorAll(".weekly-offer img").forEach((img) => {
      img.onerror = () => {
        const fallback = document.createElement("span");
        fallback.className = "weekly-photo-fallback";
        fallback.setAttribute("aria-label", "Imagen no disponible");
        fallback.textContent = "🛒";
        img.replaceWith(fallback);
      };
    });
    root.querySelector("#week-search-all").onclick = searchAll;
    root.querySelector("#week-auto-select").onclick = () => {
      const reply = autoSelect();
      root.querySelector("#week-error").textContent = reply;
    };
    root.querySelector("#week-new").onclick = () => {
      state.id = crypto.randomUUID();
      activePlan = null;
      autoRequested = false;
      persist();
      render();
    };
    root
      .querySelectorAll("[data-find]")
      .forEach((b) => (b.onclick = () => find(b.dataset.find)));
    root.querySelectorAll("[data-query]").forEach((input) => {
      input.oninput = () => {
        const row = state.rows.find((r) => r.id === input.dataset.query);
        if (!row || row.query === input.value) return;
        row.query = input.value;
        row.offers = [];
        row.selected = null;
        row.approved = [];
        row.selectionSource = null;
        row.usualPriceCents = null;
        row.error = "";
        activePlan = null;
        persist();
      };
    });
    root.querySelectorAll("[data-suggest]").forEach((button) => {
      button.onclick = () => {
        const input = root.querySelector(`[data-query="${CSS.escape(button.dataset.suggest)}"]`);
        if (!input) return;
        input.value = button.dataset.suggestQuery;
        input.dispatchEvent(new Event("input", { bubbles: true }));
        void find(button.dataset.suggest);
      };
    });
    root.querySelectorAll("[data-choose]").forEach(
      (b) =>
        (b.onclick = () =>
          select(
            state.rows.find((r) => r.id === b.dataset.choose),
            b.dataset.url,
          )),
    );
    root.querySelectorAll("[data-approve]").forEach(
      (b) =>
        (b.onchange = () => {
          const r = state.rows.find((r) => r.id === b.dataset.approve),
            chosen = r.offers.find(
              (o) => o.listing.productUrl === r.selected,
            ).listing,
            l = r.offers.find(
              (o) => o.listing.productUrl === b.dataset.url,
            ).listing;
          if (
            measure(chosen.quantity, chosen.unit)?.kind !==
            measure(l.quantity, l.unit)?.kind
          ) {
            b.checked = false;
            root.querySelector("#week-error").textContent =
              "No se pueden mezclar gramos, mililitros o piezas en una misma línea.";
            return;
          }
          r.approved = b.checked
            ? [...new Set([...r.approved, b.dataset.url])]
            : r.approved.filter((u) => u !== b.dataset.url);
          changed();
        }),
    );
    root.querySelectorAll("[data-qty]").forEach(
      (b) =>
        (b.onchange = () => {
          const r = state.rows.find((r) => r.id === b.dataset.qty),
            n = Number(b.value);
          if (
            (!soldByWeight(
              r.offers.find((o) => o.listing.productUrl === r.selected)
                ?.listing,
            ) &&
              !Number.isInteger(n)) ||
            !Number.isFinite(n) ||
            n <= 0 ||
            n > 99
          ) {
            b.value = r.packages;
            return;
          }
          r.packages = n;
          changed();
        }),
    );
    root.querySelectorAll("[data-usual]").forEach(
      (b) =>
        (b.onchange = () => {
          const value = b.value.trim() ? parseMoney(b.value) : null;
          if (b.value.trim() && value === null) {
            b.setCustomValidity("Escribe un precio válido");
            b.reportValidity();
            return;
          }
          b.setCustomValidity("");
          state.rows.find((r) => r.id === b.dataset.usual).usualPriceCents =
            value;
          changed();
        }),
    );
    root.querySelector("#week-stores").onchange = (e) => {
      state.maxStores = Number(e.target.value);
      changed();
    };
    root.querySelector("#week-hour").onchange = (e) => {
      const n = parseMoney(e.target.value);
      if (n === null) {
        e.target.value = state.hourlyCents / 100;
        return;
      }
      state.hourlyCents = n;
      changed();
    };
    root.querySelectorAll("[data-minutes],[data-trip]").forEach(
      (b) =>
        (b.onchange = () => {
          const s = b.dataset.minutes || b.dataset.trip,
            m = state.travel[s] ?? { minutes: null, costCents: null };
          const n = b.value.trim()
            ? b.dataset.minutes
              ? Number(b.value)
              : parseMoney(b.value)
            : null;
          if (
            n !== null &&
            (!Number.isFinite(n) || n < 0 || (b.dataset.minutes && n > 1440))
          ) {
            b.value = "";
            return;
          }
          if (b.dataset.minutes) m.minutes = n;
          else m.costCents = n;
          state.travel[s] = m;
          changed();
        }),
    );
    if (autoRequested && !batch) optimize(false);
  }
  function changed() {
    activePlan = null;
    persist();
    root.querySelector("#week-results").innerHTML = "";
    root.querySelector("#week-error").textContent =
      "Cambios guardados. Vuelve a optimizar.";
  }
  function optimize(scroll = true) {
    const target = root.querySelector("#week-results");
    if (!target || !state.rows.length) return;
    const openRows = state.rows.map((row) => ({ ...row, selected: null, selectionSource: null }));
    const stores = [...new Set(openRows.flatMap((row) => row.offers.map((offer) => offer.listing.retailer)))].sort();
    if (!stores.length) {
      target.innerHTML = `<div class="notice">${pending.size || batch ? "Buscando precios para comparar toda tu lista…" : "Aún no hay precios publicados vigentes. Actualiza la búsqueda o precisa productos sin opciones."}</div>`;
      return;
    }
    const singles = stores.map((store) => ({
      kind: store,
      ...recommendWeekly(openRows.map((row) => ({ ...row, offers: row.offers.filter((offer) => offer.listing.retailer === store) })), { maxStores: 1 }),
    })).sort((a, b) => b.lines.length - a.lines.length || a.total - b.total);
    const mixed = { kind: "Dos tiendas", ...recommendWeekly(openRows, { maxStores: 2 }) };
    const plans = [...singles, ...(mixed.stores.length === 2 ? [mixed] : [])];
    const one = singles[0] ?? { lines: [], complete: false, total: 0 };
    const two = mixed;
    const equivalent = state.rows.every((row) => row.requested?.unit !== "package");
    const ranked = [...plans].sort((a, b) => b.lines.length - a.lines.length || (equivalent ? a.total - b.total : a.score - b.score) || a.stores.length - b.stores.length);
    const winner = ranked[0] ?? one;
    const recommended = plans.indexOf(winner);
    const reason = winner.complete
      ? winner.stores.length === 2
        ? `La combinación de ${winner.stores.join(" y ")} tiene el menor total publicado de la lista. Traslado y envío no incluidos.`
        : `${winner.stores[0]} cubre toda la lista${equivalent ? " al mejor total publicado" : ""} en una sola visita. Traslado y envío no incluidos.`
      : "Aún faltan productos para completar la compra. Compara solo la cobertura encontrada.";
    target.innerHTML = `<section class="week-basket"><div class="week-basket-head"><span class="eyebrow">COMPARACIÓN DE TU LISTA</span><h3>¿Dónde conviene hacer todo el súper?</h3><p>${esc(reason)}</p></div><div class="week-plan-grid">${plans.map((p, i) => `<article class="week-plan-card ${recommended === i && p.lines.length ? "recommended" : ""}"><div class="week-plan-top"><span>${p.stores.length === 2 ? "Dos tiendas" : "Una tienda"}</span>${recommended === i && p.lines.length ? '<b>Recomendación</b>' : ""}</div><h4>${p.stores.length ? p.stores.map(esc).join(" + ") : esc(p.kind)}</h4><strong>${p.lines.length ? money(p.total) : "—"}</strong><p>${p.lines.length} de ${state.rows.length} productos con precio publicado${p.complete ? " · lista completa" : " · lista incompleta"}</p>${p.missing.length ? `<small>Faltan: ${p.missing.map(esc).join(", ")}</small>` : ""}${p.lines.some((line) => { const row = state.rows.find((item) => item.id === line.rowId); return row?.selected && row.selected !== line.listing.productUrl; }) ? `<small>Incluye cambios frente a tus productos elegidos. Revisa los detalles.</small>` : ""}<button type="button" class="${recommended === i ? "primary" : "secondary"} full" data-plan="${i}" ${!p.lines.length ? "disabled" : ""}>${p.complete ? "Ver lista para comprar" : "Ver productos encontrados"} →</button></article>`).join("")}</div>${!equivalent ? '<p class="comparison-help">Hay presentaciones sin tamaño definido: revisa el precio por unidad antes de comparar totales entre marcas.</p>' : ""}${mixed.stores.length < 2 && singles.length > 1 ? '<p class="comparison-help">Combinar tiendas no mejora la cobertura ni el total encontrado.</p>' : ""}<p class="comparison-help">Las opciones pueden usar marcas o presentaciones distintas. Son precios publicados, no carritos creados. Confirma disponibilidad, importe y entrega en cada comercio.</p><div id="week-handoff"></div></section>`;
    target.querySelectorAll("[data-plan]").forEach((button) => {
      button.onclick = () => handoff(plans[Number(button.dataset.plan)]);
    });
    const chosen = winner;
    if (chosen.lines.length) handoff(chosen);
    if (scroll) target.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  function handoff(p) {
    activePlan = p;
    const reference = p.complete && p.lines.every((line) => {
      const row = state.rows.find((item) => item.id === line.rowId);
      return row?.selected === line.listing.productUrl && row.usualPriceCents !== null && Number.isSafeInteger(row?.usualPriceCents);
    }) ? p.lines.reduce((sum, line) => sum + Math.round(state.rows.find((row) => row.id === line.rowId).usualPriceCents * line.packages), 0) : null;
    const previous = load("barasu-weekly-history", []);
    const snapshot = {
      id: state.id,
      date: new Date().toISOString(),
      total: p.total,
      reference,
      savings: reference === null ? null : reference - p.total,
      stores: p.stores,
      products: state.rows.map((r) => r.name),
      postal: location()?.postal_code ?? null,
    };
    if (p.complete) localStorage.setItem(
      "barasu-weekly-history",
      JSON.stringify(
        [snapshot, ...previous.filter((x) => x.id !== state.id)].slice(0, 52),
      ),
    );
    const target = root.querySelector("#week-handoff");
    target.innerHTML = `<div class="week-handoff-head"><h3>${p.complete ? "Tu compra, organizada por tienda" : "Productos encontrados"}</h3><p>${p.complete ? "Abre los productos de cada comercio y agrégalos a su carrito." : "Esta opción no cubre toda tu lista. No la presentamos como una compra completa."}</p></div>${p.stores
      .map(
        (s) =>
          `<article class="weekly-row week-store-list"><h4>${esc(s)} <span>${money(p.lines.filter((l) => l.listing.retailer === s).reduce((sum, l) => sum + l.total, 0))}</span></h4>${p.lines
            .filter((l) => l.listing.retailer === s)
            .map(
              (l) =>
                `<div class="week-buy-line">${l.listing.imageUrl ? `<img src="${esc(l.listing.imageUrl)}" alt="" loading="lazy">` : '<span class="weekly-photo-fallback">🛒</span>'}<div><strong>${esc(l.listing.productName)}</strong><small>${l.packages} ${soldByWeight(l.listing) ? "kg estimados" : "paquete(s)"} · ${money(l.total)}</small>${state.rows.find((row) => row.id === l.rowId)?.selected && state.rows.find((row) => row.id === l.rowId).selected !== l.listing.productUrl ? '<small>Alternativa a tu elección · revisa marca y presentación</small>' : ""}<a href="${esc(l.listing.productUrl)}" target="_blank" rel="noopener noreferrer">Abrir producto en ${esc(s)} ↗</a></div></div>`,
            )
            .join("")}</article>`,
      )
      .join(
        "",
      )}<p class="comparison-help">Barasu abre cada ficha para que agregues los productos al carrito del comercio. No transfiere un carrito completo ni realiza el pago. Confirma precios, existencias y envío allí; el precio por kilo puede cambiar con el pesaje.</p><button class="secondary full" id="week-export">Descargar lista con enlaces</button>${p.complete ? '<button class="primary full" id="week-record">Ya compré: registrar ahorro</button>' : ""}<div id="week-saved" role="status"></div>`;
    target.querySelector("#week-export").onclick = () => {
      const blob = new Blob([weeklyExport(p)], {
          type: "text/plain;charset=utf-8",
        }),
        url = URL.createObjectURL(blob),
        a = document.createElement("a");
      a.href = url;
      a.download = "barasu-super-semanal.txt";
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    };
    if (p.complete) target.querySelector("#week-record").onclick = () =>
      onRegister(
        {
          id: state.id,
          items: p.lines.map((l) => {
            const row = state.rows.find((r) => r.id === l.rowId);
            return {
              id: row.id,
              url: l.listing.productUrl,
              name: l.listing.productName,
              retailer: l.listing.retailer,
              priceCents: l.listing.priceCents,
              packages: l.packages,
              usualReferenceCents:
                row.usualPriceCents === null
                  ? null
                  : Math.round(row.usualPriceCents * row.packages),
              checkedAt: l.listing.checkedAt,
              postal: location()?.postal_code ?? null,
            };
          }),
          referenceCents: reference,
          totalCents: p.total,
        },
        () => {
          target.querySelector("#week-record").disabled = true;
          target.querySelector("#week-saved").textContent =
            "Compra registrada. Puedes verla en Ahorro.";
        },
      );
  }
  return { setDraft, show, prefetch: searchAll, autoSelect, invalidateLocation };
}
