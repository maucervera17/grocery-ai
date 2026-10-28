export function qualifiersMatch(name, query = "") {
  const norm = (s) =>
    s
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase();
  return [
    ...norm(query).matchAll(
      /\b(sin|con)\s+(hueso|piel|azucar|lactosa|gluten|sal)\b/g,
    ),
  ].every((q) => new RegExp(`\\b${q[1]}\\s+${q[2]}\\b`).test(norm(name)));
}
export const soldByWeight = (listing) =>
  listing?.unit === "kg" &&
  /\bpor\s+(?:kg|kilo(?:gramo)?)\b/i.test(listing.productName);
// Pure basket optimizer. Only explicitly approved offers enter the calculation.
export function measure(quantity, unit) {
  const units = {
    g: ["mass", 1],
    kg: ["mass", 1000],
    ml: ["volume", 1],
    L: ["volume", 1000],
    piece: ["count", 1],
    dozen: ["count", 12],
    package: ["package", 1],
  };
  const u = units[unit];
  return u && Number.isFinite(quantity) && quantity > 0
    ? { kind: u[0], amount: quantity * u[1] }
    : null;
}
// Recommend only source-backed, fresh offers. Existing manual choices remain fixed.
// With an unspecified presentation, compare unit prices within one dimension.
export function recommendWeekly(rows, { maxStores = 2, now = Date.now() } = {}) {
  if (![1, 2].includes(maxStores)) throw Error("Límite de tiendas inválido");
  const candidates = rows.map((row) => {
    const requested = measure(row.requested?.quantity, row.requested?.unit);
    const unspecified = row.requested?.unit === "package";
    const manual = row.selected && row.selectionSource !== "auto";
    let options = (row.offers ?? []).flatMap((offer) => {
      const listing = offer.listing;
      const pack = measure(listing?.quantity, listing?.unit);
      const age = now - Date.parse(listing?.checkedAt);
      if (
        !pack || !requested || (!unspecified && requested.kind !== pack.kind) ||
        !qualifiersMatch(listing.productName, row.query ?? row.name) ||
        !Number.isSafeInteger(listing.priceCents) || listing.priceCents < 0 ||
        typeof listing.productUrl !== "string" || !/^https:\/\//.test(listing.productUrl) ||
        typeof listing.retailer !== "string" || !listing.retailer ||
        !Number.isFinite(age) || age < 0 || age > 3600000 ||
        (manual && listing.productUrl !== row.selected)
      ) return [];
      const count = unspecified
        ? requested.amount
        : soldByWeight(listing)
          ? Math.ceil((requested.amount / pack.amount) * 1000 - 1e-9) / 1000
          : Math.ceil(requested.amount / pack.amount - 1e-9);
      if (!Number.isFinite(count) || count <= 0 || count > 99) return [];
      return [{ rowId: row.id, listing, packages: count,
        total: Math.round(listing.priceCents * count),
        unitCost: listing.priceCents / pack.amount,
        dimension: pack.kind, unspecified, manual }];
    });
    if (unspecified) {
      const counts = new Map();
      for (const option of options) counts.set(option.dimension, (counts.get(option.dimension) ?? 0) + 1);
      const ranked = [...counts].sort((a, b) => b[1] - a[1]);
      if (ranked.length > 1 && ranked[0][1] === ranked[1][1]) return [];
      if (ranked.length) options = options.filter((option) => option.dimension === ranked[0][0]);
    }
    return options;
  });
  const stores = [...new Set(candidates.flatMap((list) => list.map((x) => x.listing.retailer)))].sort();
  const hasUnspecified = candidates.some((list) => list.some((item) => item.unspecified));
  const floor = candidates.map((list) => Math.min(...list.map((item) => item.unspecified ? item.unitCost : item.total)));
  const subsets = stores.map((store) => [store]);
  if (maxStores === 2)
    for (let a = 0; a < stores.length; a++)
      for (let b = a + 1; b < stores.length; b++) subsets.push([stores[a], stores[b]]);
  const plans = subsets.map((subset) => {
    const lines = candidates.flatMap((list) => {
      const best = list.filter((item) => subset.includes(item.listing.retailer))
        .sort((a, b) => (a.unspecified ? a.unitCost - b.unitCost : a.total - b.total) ||
          a.total - b.total || a.listing.productUrl.localeCompare(b.listing.productUrl))[0];
      return best ? [best] : [];
    });
    const score = lines.reduce((sum, item) => {
      const index = rows.findIndex((row) => row.id === item.rowId);
      return sum + (item.unspecified ? item.unitCost : item.total) / Math.max(1, floor[index]);
    }, 0);
    return { lines, stores: [...new Set(lines.map((x) => x.listing.retailer))],
      total: lines.reduce((sum, item) => sum + item.total, 0), score };
  });
  plans.sort((a, b) => b.lines.length - a.lines.length || (hasUnspecified ? a.score - b.score : a.total - b.total) || a.total - b.total || a.stores.length - b.stores.length);
  const best = plans[0] ?? { lines: [], stores: [], total: 0, score: 0 };
  return { ...best, complete: rows.length > 0 && best.lines.length === rows.length,
    missing: rows.filter((row) => !best.lines.some((line) => line.rowId === row.id)).map((row) => row.name) };
}
export function optimizeWeekly(
  rows,
  { maxStores = 2, travel = {}, hourlyCents = 0, now = Date.now() } = {},
) {
  if (
    ![1, 2].includes(maxStores) ||
    !Number.isSafeInteger(hourlyCents) ||
    hourlyCents < 0
  )
    throw Error("Preferencias inválidas");
  const candidates = rows.map((row) => {
    const base = row.offers?.find(
      (o) => o.listing.productUrl === row.selected,
    )?.listing;
    const wanted = base && measure(base.quantity * row.packages, base.unit);
    if (
      !wanted ||
      (!soldByWeight(base) && !Number.isInteger(row.packages)) ||
      !Number.isFinite(row.packages) ||
      row.packages <= 0 ||
      row.packages > 99
    )
      return [];
    return (row.offers ?? [])
      .filter(
        (o) =>
          row.approved?.includes(o.listing.productUrl) &&
          qualifiersMatch(o.listing.productName, row.query ?? row.name),
      )
      .flatMap((o) => {
        const l = o.listing,
          p = measure(l.quantity, l.unit),
          age = now - Date.parse(l.checkedAt);
        if (
          !p ||
          p.kind !== wanted.kind ||
          !Number.isSafeInteger(l.priceCents) ||
          l.priceCents < 0 ||
          age < 0 ||
          age > 3600000
        )
          return [];
        const count = soldByWeight(l)
          ? Math.ceil((wanted.amount / p.amount) * 1000 - 1e-9) / 1000
          : Math.ceil(wanted.amount / p.amount - 1e-9);
        if (count > 999) return [];
        return [
          {
            rowId: row.id,
            listing: l,
            packages: count,
            total: Math.round(count * l.priceCents),
            requestedAmount: wanted.amount,
            suppliedAmount: count * p.amount,
            dimension: p.kind,
          },
        ];
      });
  });
  const stores = [
    ...new Set(candidates.flatMap((cs) => cs.map((c) => c.listing.retailer))),
  ].sort();
  const subsets = stores.map((s) => [s]);
  if (maxStores === 2)
    for (let i = 0; i < stores.length; i++)
      for (let j = i + 1; j < stores.length; j++)
        subsets.push([stores[i], stores[j]]);
  const plans = subsets.map((set) => {
    const lines = candidates
      .map(
        (cs) =>
          cs
            .filter((c) => set.includes(c.listing.retailer))
            .sort(
              (a, b) =>
                a.total - b.total ||
                a.listing.productUrl.localeCompare(b.listing.productUrl),
            )[0],
      )
      .filter(Boolean);
    const used = [...new Set(lines.map((c) => c.listing.retailer))];
    const metrics = used.map((s) => travel[s]);
    const travelKnown = metrics.every(
      (m) =>
        m &&
        Number.isFinite(m.minutes) &&
        m.minutes >= 0 &&
        Number.isSafeInteger(m.costCents) &&
        m.costCents >= 0,
    );
    const minutes = travelKnown
      ? metrics.reduce((n, m) => n + m.minutes, 0)
      : null;
    const travelCents = travelKnown
      ? metrics.reduce((n, m) => n + m.costCents, 0)
      : null;
    const total = lines.reduce((n, c) => n + c.total, 0);
    const reference =
      rows.length &&
      rows.every(
        (r) =>
          Number.isSafeInteger(r.usualPriceCents) &&
          r.usualPriceCents >= 0 &&
          r.selected,
      )
        ? rows.reduce(
            (n, r) => n + Math.round(r.usualPriceCents * r.packages),
            0,
          )
        : null;
    const complete = lines.length === rows.length && rows.length > 0;
    return {
      stores: used,
      lines,
      missing: rows
        .filter((r) => !lines.some((l) => l.rowId === r.id))
        .map((r) => r.name),
      complete,
      total,
      reference: complete ? reference : null,
      savings: complete && reference !== null ? reference - total : null,
      minutes,
      travelCents,
      effectiveTotal: travelKnown
        ? total + travelCents + Math.round((minutes * hourlyCents) / 60)
        : null,
    };
  });
  const rank = (a, b) =>
    b.lines.length - a.lines.length ||
    a.total - b.total ||
    a.stores.length - b.stores.length;
  plans.sort(rank);
  const complete = plans.filter((p) => p.complete);
  return {
    plans,
    cheapest: complete[0] ?? null,
    single: complete.filter((p) => p.stores.length === 1).sort(rank)[0] ?? null,
    convenient:
      complete
        .filter((p) => p.effectiveTotal !== null)
        .sort(
          (a, b) =>
            a.effectiveTotal - b.effectiveTotal ||
            a.stores.length - b.stores.length,
        )[0] ?? null,
  };
}
export function weeklyExport(plan) {
  return (
    plan.stores
      .map(
        (store) =>
          `${store}\n` +
          plan.lines
            .filter((l) => l.listing.retailer === store)
            .map(
              (l) =>
                `${l.packages} ${soldByWeight(l.listing) ? "kg estimados de" : "×"} ${l.listing.productName} — $${(l.total / 100).toFixed(2)}\n${l.listing.productUrl}`,
            )
            .join("\n"),
      )
      .join("\n\n") +
    "\n\nPrecios observados; confirma precio y disponibilidad en la tienda. No se creó un carrito ni un pedido."
  );
}
export function recordWeeklyPurchase(
  snapshot,
  purchases,
  paidCents,
  date = new Date().toISOString(),
) {
  if (!snapshot?.items?.length || !snapshot.id) throw Error("Lista vacía");
  if (purchases.some((p) => p.id === snapshot.id))
    throw Error("Esta lista ya tiene una compra registrada");
  if (
    !Number.isSafeInteger(paidCents) ||
    paidCents < 0 ||
    paidCents > 100000000
  )
    throw Error("Importe pagado inválido");
  const reference = snapshot.items.every(
    (i) =>
      Number.isSafeInteger(i.usualReferenceCents) && i.usualReferenceCents >= 0,
  )
    ? snapshot.items.reduce((n, i) => n + i.usualReferenceCents, 0)
    : null;
  return {
    id: snapshot.id,
    date,
    items: structuredClone(snapshot.items),
    paidCents,
    referenceCents: reference,
    differenceCents: reference === null ? null : reference - paidCents,
  };
}
