import {
  optimizeWeekly,
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
const esc = (v) =>
  String(v ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
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
    working = false,
    batch = false;
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
      persist();
    }
  }
  function setDraft(items) {
    invalidateLocation();
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
      }
    }
    activePlan = null;
    persist();
    render();
  }
  function show() {
    invalidateLocation();
    render();
    root.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  async function find(id) {
    if (working) return;
    const row = state.rows.find((r) => r.id === id);
    if (!row) return;
    const query =
      root.querySelector(`[data-query="${CSS.escape(id)}"]`)?.value.trim() ||
      row.query;
    if (!query) return;
    if (query !== row.query) {
      row.offers = [];
      row.selected = null;
      row.approved = [];
      row.usualPriceCents = null;
      activePlan = null;
    }
    row.query = query;
    working = true;
    render();
    try {
      const result = await search(query);
      row.error = result?.errors?.map((e) => e.message).join(" ") || "";
      if (result?.comparison?.data_mode === "live") {
        row.offers = result.comparison.offers;
        row.scope = result.comparison.scope;
        row.selected = null;
        row.approved = [];
        row.usualPriceCents = null;
        activePlan = null;
        row.error = row.offers.length
          ? row.error
          : row.error ||
            "No hay ofertas. Prueba una presentación o marca específica.";
      } else
        row.error =
          result?.reply ||
          "No se pudo consultar. Conservamos tu selección anterior.";
    } finally {
      working = false;
      persist();
      render();
    }
  }
  function select(row, url) {
    const l = row.offers.find((o) => o.listing.productUrl === url)?.listing;
    if (!l) return;
    row.selected = url;
    row.approved = [url];
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
  function render() {
    root.hidden = false;
    root.innerHTML = `<section class="weekly"><div class="card-top"><h2>Mi súper semanal</h2><span>${state.rows.filter((r) => r.selected).length}/${state.rows.length} elegidos</span></div><button class="secondary full" id="week-search-all" ${working || batch || !state.rows.length ? "disabled" : ""}>${batch ? "Buscando tu lista…" : "Buscar opciones para toda mi lista"}</button><button class="weekly-new secondary" id="week-new">Nueva semana · conservar productos</button><p class="comparison-help">Elige presentaciones y alternativas que sí comprarías. Marca, corte y calidad los decides tú.</p>${
      !state.rows.length
        ? "<p>Escribe una lista: «Quiero huevos, pollo, carne y queso».</p>"
        : state.rows
            .map(
              (r, index) =>
                `<article class="weekly-row"><h3>${index + 1}. ${esc(r.name)}</h3><div class="weekly-query"><input data-query="${esc(r.id)}" aria-label="Buscar presentación de ${esc(r.name)}" value="${esc(r.query)}" placeholder="Ej. pechuga sin hueso, 1 kg"><button data-find="${esc(r.id)}" ${working ? "disabled" : ""}>${working ? "Consultando…" : r.offers.length ? "Buscar otra" : "Ver opciones"}</button></div>${/^(carne|pollo|queso)$/i.test(r.name) ? '<p class="comparison-help">Especifica el corte, tipo o marca para comparar productos que sí te sirven.</p>' : ""}${r.error ? `<details class="weekly-warning"><summary>Avisos de las fuentes</summary>${esc(r.error)}</details>` : ""}${
                  r.offers.length
                    ? `<div class="weekly-options">${r.offers
                        .map((o) => {
                          const l = o.listing,
                            selected = r.selected === l.productUrl;
                          return `<div class="weekly-offer ${selected ? "chosen" : ""}">${l.imageUrl ? `<img src="${esc(l.imageUrl)}" alt="${esc(l.productName)}" loading="lazy">` : ""}<div><strong>${esc(l.productName)}</strong><small>${esc(l.retailer)} · ${money(l.priceCents)}<br>${money(o.basis === "piece" || o.basis === "package" ? o.unit_price_cents_per_100 / 100 : o.unit_price_cents_per_100)} / ${o.basis === "piece" ? "pieza" : o.basis === "package" ? "paquete" : "100 " + esc(o.basis)}</small><button data-choose="${esc(r.id)}" data-url="${esc(l.productUrl)}" ${working ? "disabled" : ""}>${selected ? "✓ Elegido" : "Elegir"}</button>${r.selected && !selected ? `<label class="approve"><input type="checkbox" data-approve="${esc(r.id)}" data-url="${esc(l.productUrl)}" ${r.approved.includes(l.productUrl) ? "checked" : ""}> También acepto esta alternativa</label>` : ""}</div></div>`;
                        })
                        .join(
                          "",
                        )}</div><small>${r.scope === "local" ? "Zona verificada al consultar" : "Precios publicados; existencias locales sin confirmar"} · ${esc(location()?.postal_code || "Sin CP")}</small>`
                    : ""
                }${r.selected ? `<div class="weekly-fields"><label>${soldByWeight(r.offers.find((o) => o.listing.productUrl === r.selected)?.listing) ? "Kilos (estimados)" : "Paquetes"}<input data-qty="${esc(r.id)}" type="number" min="0.001" step="0.001" max="99" value="${r.packages}"></label><label>Mi precio habitual / presentación o kg (MXN)<input data-usual="${esc(r.id)}" inputmode="decimal" placeholder="Sin referencia" value="${r.usualPriceCents === null ? "" : (r.usualPriceCents / 100).toFixed(2)}"></label></div><p class="comparison-help">La referencia corresponde al producto elegido. Aprobar alternativas expresa tu preferencia, no una certificación de calidad.</p>` : ""}</article>`,
            )
            .join("")
    }<details class="weekly-preferences"><summary>Costo y conveniencia</summary><label>Máximo de tiendas<select id="week-stores"><option value="1" ${state.maxStores === 1 ? "selected" : ""}>Una tienda</option><option value="2" ${state.maxStores === 2 ? "selected" : ""}>Hasta dos tiendas</option></select></label><label>Valor de una hora de tu tiempo (MXN)<input id="week-hour" inputmode="decimal" value="${state.hourlyCents / 100}"></label><p class="comparison-help">Opcional: indica el tiempo total de visita y traslado desde tu ubicación, y el costo de traslado o envío. Son estimaciones tuyas, no rutas medidas. Para dos tiendas sumamos las visitas por separado.</p>${[...new Set(state.rows.flatMap((r) => r.offers.map((o) => o.listing.retailer)))].map((s) => `<fieldset><legend>${esc(s)}</legend><label>Minutos por visita<input data-minutes="${esc(s)}" type="number" min="0" max="1440" value="${state.travel[s]?.minutes ?? ""}" placeholder="Sin estimación"></label><label>Traslado o envío (MXN)<input data-trip="${esc(s)}" inputmode="decimal" value="${state.travel[s]?.costCents == null ? "" : state.travel[s].costCents / 100}" placeholder="Sin estimación"></label><a href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(s + " cerca de " + (location()?.postal_code || "mí"))}" target="_blank" rel="noopener noreferrer">Buscar sucursal en mapas ↗</a></fieldset>`).join("")}</details><div id="week-error" role="status"></div><button class="primary full" id="week-optimize" ${working || !state.rows.length ? "disabled" : ""}>Optimizar mi lista</button><div id="week-results"></div></section>`;
    root.querySelector("#week-search-all").onclick = async () => {
      if (working || batch) return;
      batch = true;
      try {
        for (const row of state.rows)
          if (
            !row.offers.length ||
            row.offers.some(
              (o) => Date.now() - Date.parse(o.listing.checkedAt) > 3600000,
            )
          )
            await find(row.id);
      } finally {
        batch = false;
        render();
      }
    };
    root.querySelector("#week-new").onclick = () => {
      state.id = crypto.randomUUID();
      activePlan = null;
      persist();
      render();
    };
    root
      .querySelectorAll("[data-find]")
      .forEach((b) => (b.onclick = () => find(b.dataset.find)));
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
    root.querySelector("#week-optimize").onclick = optimize;
  }
  function changed() {
    activePlan = null;
    persist();
    root.querySelector("#week-results").innerHTML = "";
    root.querySelector("#week-error").textContent =
      "Cambios guardados. Vuelve a optimizar.";
  }
  function optimize() {
    const results = optimizeWeekly(state.rows, state);
    const target = root.querySelector("#week-results");
    if (!results.cheapest) {
      target.innerHTML = `<div class="notice">La lista aún no tiene cobertura completa. Elige una oferta vigente para cada producto o acepta más alternativas. No calculamos ahorro de una lista incompleta.${results.plans[0]?.missing.length ? "<br>Faltan: " + results.plans[0].missing.map(esc).join(", ") : ""}</div>`;
      return;
    }
    const options = [
      ["Menor precio", results.cheapest],
      ["Una sola tienda", results.single],
      ["Con tiempo y traslado", results.convenient],
    ];
    target.innerHTML = `<div class="week-scenarios">${options.map(([label, p], i) => `<article><h3>${label}</h3>${p ? `<strong>${money(p.total)}</strong><p>${p.stores.map(esc).join(" + ")}</p><small>${p.savings === null ? "Completa tu precio habitual para estimar ahorro." : `Diferencia vs habitual: ${money(p.savings)}`}</small>${i === 2 ? `<p>${p.minutes} min · traslado ${money(p.travelCents)}<br>Costo con valor del tiempo: ${money(p.effectiveTotal)}</p>` : ""}<button class="secondary full" data-plan="${i}">Usar esta opción</button>` : "<p>No hay datos suficientes para esta opción.</p>"}</article>`).join("")}</div><div id="week-handoff"></div>`;
    target
      .querySelectorAll("[data-plan]")
      .forEach(
        (b) => (b.onclick = () => handoff(options[Number(b.dataset.plan)][1])),
      );
    handoff(results.cheapest);
    target.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  function handoff(p) {
    activePlan = p;
    const previous = load("barasu-weekly-history", []);
    const snapshot = {
      id: state.id,
      date: new Date().toISOString(),
      total: p.total,
      reference: p.reference,
      savings: p.savings,
      stores: p.stores,
      products: state.rows.map((r) => r.name),
      postal: location()?.postal_code ?? null,
    };
    localStorage.setItem(
      "barasu-weekly-history",
      JSON.stringify(
        [snapshot, ...previous.filter((x) => x.id !== state.id)].slice(0, 52),
      ),
    );
    const target = root.querySelector("#week-handoff");
    target.innerHTML = `<h3>Tu lista por tienda</h3>${p.stores
      .map(
        (s) =>
          `<article class="weekly-row"><h4>${esc(s)}</h4>${p.lines
            .filter((l) => l.listing.retailer === s)
            .map(
              (l) =>
                `<p>${l.packages} ${soldByWeight(l.listing) ? "kg estimados de" : "×"} ${esc(l.listing.productName)} · ${money(l.total)}<br><a href="${esc(l.listing.productUrl)}" target="_blank" rel="noopener noreferrer">Agregar en el sitio de la tienda ↗</a></p>`,
            )
            .join("")}</article>`,
      )
      .join(
        "",
      )}<p class="comparison-help">Lista preparada. Abre cada producto y agrégalo al carrito del comercio. Barasu todavía no transfiere un carrito completo ni realiza el pago. Confirma precios, existencias y envío en la tienda. En productos por kilo, el importe final depende del pesaje.</p><button class="secondary full" id="week-export">Descargar lista con enlaces</button><button class="primary full" id="week-record">Ya compré: registrar ahorro</button><div id="week-saved" role="status"></div>`;
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
    target.querySelector("#week-record").onclick = () =>
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
          referenceCents: p.reference,
          totalCents: p.total,
        },
        () => {
          target.querySelector("#week-record").disabled = true;
          target.querySelector("#week-saved").textContent =
            "Compra registrada. Puedes verla en Ahorro.";
        },
      );
  }
  return { setDraft, show, invalidateLocation };
}
