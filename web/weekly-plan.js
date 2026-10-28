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
