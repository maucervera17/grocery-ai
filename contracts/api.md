# API v0.2 — propuesta local basada en el acuerdo actualizado

`POST /v1/chat/search` acepta una unión discriminada por `action`. Fuente de tipos: `schema.ts`. Ejecutar `npm run contracts` para generar JSON Schema. Este cambio rompe la versión anterior: no hay `conversation_id` ni `results`.

## update_draft

Request: `{action: "update_draft", message, items, location?: null | {postal_code}}`.
`message`: 1–2000 caracteres. `items`: borrador actual, hasta 20 elementos con IDs únicos.
Cada elemento: `{client_item_id, name, quantity, unit, notes}`. `notes` debe ser texto o null. Cantidades positivas, máximo 100000 y precisión de 0.001. Unidades: g, kg, ml, L, piece, package, dozen.

Response: `{reply, status, draft_items, plan: null, errors}`. El agente usa operaciones validadas. Preserva IDs existentes; los nuevos se generan en el backend. Una aclaración o fallo mantiene el borrador original completo. iOS no debe reemplazar su borrador por respuestas HTTP inválidas.

## compare

Request: `{action: "compare", message?: null, items, location?: null | {postal_code}, preferences?: {max_stores: 1 | 2}}`. Por defecto max_stores=2. El borrador enviado no se modifica.

Response: `{reply, status, draft_items, plan, errors}`. Plan contiene total_price_cents, estimated_savings_cents, currency, stores y unmatched_items. Cada tienda incluye retailer, store_name, subtotal_cents e items. Cada línea especifica cantidad solicitada, tamaño del paquete, número entero de paquetes, precio unitario del paquete y total de línea. El esquema completo está en `chat-search.response.schema.json` y hay ejemplos ejecutables en `fixtures/`.

Los totales cubren solo los productos asignados. Para una cesta completa todos los elementos deben estar asignados. La cesta vacía devuelve plan con total=0, sin tiendas y ahorro=null. La ausencia total de coincidencias devuelve status=error y faltantes explícitos. Los datos demo nunca se mezclan con precios reales.

`unit_price_cents_per_100`: por 100 g o 100 ml, redondeo al centavo más cercano; null para piezas, docenas y paquetes. `line_total_cents=price_cents*package_count`. El redondeo de cantidades para comprar paquetes se hace hacia arriba.

`estimated_savings_cents`: mejor cesta completa en una tienda menos plan recomendado; null si no existe referencia completa, hay estados de procedencia diferentes o datos vencidos. No se calcula desde regular_price_cents.

## Errores y estados

Error: `{code, message, client_item_id: string | null, retryable: boolean}`. Los errores generales usan null. La respuesta no expone credenciales ni texto crudo del proveedor.

- complete: operación completada sin incidencias; puede ser un borrador o comparación vacía.
- partial: aclaración sin cambios al borrador, o comparación con resultados y limitaciones/faltantes.
- error: fallo de interpretación, o comparación con incidencias y sin resultados.
- HTTP 400: JSON inválido/contrato inválido; 413: cuerpo excesivo; 415: tipo no soportado; 500: fallo interno inesperado. Fallos del modelo/fuentes tienen HTTP 200 y status error/partial para mantener un contrato uniforme.

Principales códigos: AGENT_NOT_CONFIGURED, AGENT_FAILED, CLARIFICATION_REQUIRED, SOURCES_NOT_CONFIGURED, SOURCE_TIMEOUT, SOURCE_FAILED, SOURCE_INVALID, FIRECRAWL_AUTH, FIRECRAWL_CREDITS, CACHE_FAILED, SAVE_FAILED, STALE_DATA, LOCATION_UNVERIFIED.

## Decisiones propuestas para confirmar con el equipo

- `unmatched_items`: `{client_item_id, name, reason}`. Reasons: NO_MATCH, INCOMPATIBLE_UNIT, STORE_LIMIT, SOURCE_FAILED, NOTES_REQUIRE_REVIEW.
- Errores globales admiten client_item_id=null.
- Ampliar también ScrapedListing.unit con package y dozen. Solo convertir dozen a 12 piezas; package nunca se interpreta como peso/contenido sin evidencia.
- Las notas especiales quedan sin asignar hasta implementar verificación de restricciones.
- Una presentación por línea; no mezclar SKUs ni fusionar líneas repetidas en el optimizador inicial.
- Sucursales distintas cuentan como tiendas diferentes. Sin validación de ubicación, live responde partial con LOCATION_UNVERIFIED.
- TTL de precio: una hora. Priorizar ofertas recientes frente a vencidas para el mismo producto.

Estos detalles resuelven vacíos del acuerdo para poder probar localmente; no implican aprobación del equipo ni cambios en GitHub.

## Repositorio de datos

`ListingRepository.search(query, signal)` devuelve solo ofertas reales, aisladas por código postal; `upsert(listings, query, signal)` hace persistencia idempotente mediante el adaptador único. Nunca devolver seeds de demo como registros reales. Respetar AbortSignal, el TTL y la identidad de fuente/URL/sucursal.
