const dateLabel = (value) => {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? "Fecha no disponible"
    : date.toLocaleDateString("es-MX", { day: "numeric", month: "short", year: "numeric" });
};

export function savingsMarkup(purchases, estimates, removedCount, money, esc) {
  const known = purchases.filter((purchase) => Number.isSafeInteger(purchase.differenceCents));
  const difference = known.reduce((sum, purchase) => sum + purchase.differenceCents, 0);
  const totalPaid = purchases.reduce((sum, purchase) => sum + (Number.isSafeInteger(purchase.paidCents) ? purchase.paidCents : 0), 0);
  const headline = !known.length ? purchases.length ? "Sin referencia" : "Sin compras aún" : difference > 0 ? money(difference) : difference < 0 ? `−${money(-difference)}` : money(0);
  const meaning = !known.length
    ? purchases.length ? "Tus compras no tienen un precio habitual completo." : "Registra una compra para ver aquí la diferencia."
    : difference > 0
      ? "Menos que tu precio habitual declarado"
      : difference < 0
        ? "Más que tu precio habitual declarado"
        : "Igual a tu precio habitual declarado";

  return `<div class="savings-dashboard">
    <div class="savings-heading"><span class="eyebrow">TU HISTORIAL</span><h2>Tu ahorro</h2><p>Revisa lo que pagaste y compáralo con tu precio habitual.</p></div>
    <section class="savings-hero ${difference < 0 && known.length ? "negative" : ""}">
      <span class="savings-kicker">Diferencia registrada</span>
      <strong class="savings-amount">${headline}</strong>
      <p>${meaning}</p>
      <small>Precio habitual que ingresaste − importe que confirmaste al comprar.</small>
    </section>
    <div class="savings-metrics">
      <div><span>Compras registradas</span><strong>${purchases.length}</strong></div>
      <div><span>Con referencia completa</span><strong>${known.length}</strong></div>
    </div>
    ${purchases.length ? `<p class="savings-paid">Total pagado en compras registradas <strong>${money(totalPaid)}</strong></p>` : ""}
    <section class="savings-section"><div class="savings-section-head"><h3>Compras realizadas</h3><span>${purchases.length}</span></div>
      ${purchases.length ? purchases.map((purchase) => `<article class="savings-entry">
        <div class="savings-entry-top"><div><span class="savings-badge confirmed">Compra registrada</span><h4>${esc(dateLabel(purchase.date))}</h4><small>${Array.isArray(purchase.items) ? purchase.items.length : 0} productos</small></div><strong class="${purchase.differenceCents < 0 ? "negative-text" : ""}">${purchase.differenceCents === null ? "Sin referencia" : purchase.differenceCents >= 0 ? `+${money(purchase.differenceCents)}` : `−${money(-purchase.differenceCents)}`}</strong></div>
        <div class="savings-entry-numbers"><span>Pagaste <b>${money(purchase.paidCents)}</b></span><span>Habitual <b>${purchase.referenceCents === null ? "Sin completar" : money(purchase.referenceCents)}</b></span></div>
        <details><summary>Ver detalles</summary><p>${(purchase.items ?? []).map((item) => esc(item.name ?? item.productName ?? "Producto")).join(", ") || "Sin detalle de productos"}</p><button class="savings-remove" data-delete-purchase="${esc(purchase.id)}">Eliminar registro</button></details>
      </article>`).join("") : `<div class="savings-empty"><span aria-hidden="true">🧾</span><h4>Tu historial empieza con una compra</h4><p>Elige productos en Mi lista, añade tu precio habitual y registra cuánto pagaste después de comprar.</p><button class="primary full" id="savings-open-list">Ir a Mi lista</button></div>`}
      ${removedCount ? '<button class="savings-restore" id="restore-purchase">Restaurar último registro eliminado</button>' : ""}
    </section>
    <section class="savings-section"><div class="savings-section-head"><h3>Listas preparadas</h3><span>${estimates.length}</span></div><p class="savings-section-note">Son planes, todavía no compras. Los precios pueden cambiar en la tienda.</p>
      ${estimates.length ? estimates.map((entry) => `<article class="savings-entry prepared"><div class="savings-entry-top"><div><span class="savings-badge">Solo estimación</span><h4>${esc(dateLabel(entry.date))}</h4><small>${esc((entry.stores ?? []).join(" + "))}</small></div><strong>${money(entry.total)}</strong></div><p>${(entry.products ?? []).map(esc).join(", ")}</p><div class="savings-estimate">${entry.savings === null ? "Agrega tu precio habitual para estimar la diferencia." : `Diferencia estimada vs habitual: <strong>${entry.savings < 0 ? `−${money(-entry.savings)}` : `+${money(entry.savings)}`}</strong>`}</div></article>`).join("") : `<p class="savings-section-empty">Aún no has preparado una lista completa.</p>`}
    </section>
    <details class="savings-method"><summary>¿Cómo se calcula?</summary><p>La diferencia de cada compra es la suma de tus precios habituales para los mismos productos menos el total que confirmaste haber pagado. Si falta algún precio habitual, esa compra no entra en la cifra acumulada. Una diferencia negativa significa que pagaste más.</p><p>Los importes son declarados por ti y se guardan en este navegador. No incluyen envío ni prueban cuánto habrías gastado sin Barasu.</p></details>
  </div>`;
}
