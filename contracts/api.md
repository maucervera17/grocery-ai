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

## Validación de ubicación (prototipo)

`location` acepta `postal_code`, `fulfillment` opcional (`delivery` por defecto o `pickup`) y `pickup_store` opcional (`chedraui-bellavista`). Para recogida se requiere CP `52994` y esa sucursal. No se interpreta el CP de la sucursal como domicilio del usuario. La entrega de prueba sigue usando `52997`.

Con CP, el modo live solo planifica ofertas con evidencia de destino aplicado en la ficha del producto, disponibilidad y fecha inferior a cinco minutos. No basta incluir el CP en el buscador ni en un campo de texto. `verified_postal_code` y `verified_fulfillment` identifican la confirmación en cada línea. La disponibilidad es una observación, no una reserva. Sin evidencia no se devuelve un precio alternativo de otra zona.

La migración `202610280003_postal_evidence.sql` añade `location_evidence` a las ofertas y a los RPC de lectura/escritura. Los registros anteriores sin evidencia siguen siendo utilizables para consultas generales sin CP, pero no para validar un destino.

Limitaciones verificadas: Walmart solicitó verificación humana y después mostró un error técnico al guardar 52997. Firecrawl tampoco confirmó ese destino. Chedraui Bellavista pudo seleccionarse en Chrome, pero su selección desde Firecrawl aún falla; esa observación del navegador no alimenta los precios automáticos. Para entrega Chedraui requiere dirección: `LOCATION_REQUIRES_ADDRESS`. No se ha implementado un flujo de dirección de entrega. Estos bloqueos impiden considerar terminada la validación real por CP. La web permite elegir ambas modalidades; iOS todavía usa entrega por defecto.

## product_prices — consulta directa de un producto

`{action:"product_prices", message, items, location?}` interpreta una pregunta como «Hola, quiero revisar el queso oaxaca en que tienda tiene el mejor precio?». Interpreta el producto en una lista vacía y conserva `draft_items` sin modificar: una consulta de precio no es una compra de una pieza ni una comparación del borrador anterior.

La respuesta añade `comparison` con `query`, `scope:"published"`, `data_mode`, `requested_postal_code`, `offers` (listing, costo por 100 unidades y basis) y `winner_url`. Obtiene precios publicados en las tres fuentes, compara contenido equivalente (g/kg, ml/L), conserva presentación, fuente, fecha y enlace. Solo declara un ganador cuando las dimensiones son compatibles. El ganador es entre las opciones obtenidas, no un mínimo exhaustivo del catálogo. Marcas distintas se identifican como alternativas.

El resultado es `partial` porque el precio publicado no confirma existencias en la ubicación solicitada. La disponibilidad por CP sigue siendo responsabilidad del flujo `compare`, que exige evidencia. La web distingue explícitamente los precios publicados de la validación local; no utiliza precios demo como alternativa a fallos reales. Solo muestra tarjetas después de una solicitud, y las preguntas de precio consultan directamente sin exigir un clic adicional.

### Fotos de producto

`ScrapedListing.imageUrl` es opcional y procede de metadatos de la ficha principal (`og:image`), con HTTPS y hosts CDN de las tiendas permitidos. No se toman imágenes de recomendaciones ni logotipos. La web las muestra después de la solicitud, con texto alternativo y respaldo si no cargan. Se renueva una caché que carece de imágenes. La migración 004 se aplicó en el proyecto Supabase de Barasu el 28 de octubre de 2026 mediante SQL Editor: cinco ofertas de leche devolvieron foto desde la API y una segunda lectura RPC devolvió las cinco URLs almacenadas. Las observaciones antiguas obtienen foto al volver a consultarse desde la fuente. El SQL Editor no registra la ejecución en el historial de Supabase CLI; antes de usar `supabase db push` en ese proyecto hay que conciliar las migraciones 001–004 con `supabase migration repair` desde una cuenta con acceso.

## Consulta local explícita y robustez del catálogo

`product_prices.price_scope` acepta `published` (predeterminado, precios de referencia) o `local` (requiere location). En local, tanto caché como resultados nuevos deben llevar evidencia coincidente de CP, modalidad, sucursal si aplica y observación menor a cinco minutos. Un fallo no cambia automáticamente a published. La web ofrece esa alternativa mediante una acción explícita, limpia resultados al cambiar ubicación y activa local al cambiar CP.

`comparison.unit_winners` identifica ganadores por dimensión cuando hay al menos dos fuentes comparables. No se declara ganador entre gramos y mililitros, ni entre tiendas si solo respondió una. Los sinónimos de categoría, plurales comunes y el error de marca Axxe/Axe se normalizan. Precio principal, variación seleccionada y existencias de otras variantes se interpretan por separado.

Las llamadas reales a Firecrawl se espacian 6.5 s por endpoint; los límites 429 se informan explícitamente sin reintento inmediato. El servidor permite hasta 90 s por consulta y el cliente espera hasta 95 s. Las pruebas usan un transporte simulado sin esperas. El informe de consultas reales está en `docs/CATALOG_TEST_REPORT.md`.
