# Firecrawl: Chedraui y Bodega Aurrera

`retailers.ts` define dominios y parsers; `firecrawl.ts` implementa descubrimiento y extracción. No hay API pública paralela ni escritura directa a base de datos.

1. POST `/v2/search`, restringido al dominio de cada fuente.
2. Filtrar URLs de producto y quitar parámetros de tracking.
3. POST `/v2/scrape` con markdown, maxAge=0, proxy basic y timeout.
4. Parsear solo la ficha principal. Validar con ScrapedListing.
5. Devolver listings y errores por fuente; el backend calcula el plan y decide persistencia.

Cada fuente procesa máximo dos fichas por producto. 429/5xx admite un reintento con espera breve y respetando la señal global. 401/402 no se reintentan. No se extraen precios desde snippets ni se confunden cuotas/promociones con precio base. Una ficha inválida no elimina las fichas válidas de la otra fuente.

Se preserva cachedAt cuando Firecrawl declara cacheState=hit; si falta, se rechaza. Chedraui requiere MXN explícito en metadatos y coincidencia del precio con el visible. Bodega Aurrera requiere Precio actual MXN$ y usa la variante de Tamaño cuando existe.

Limitaciones: HTML/Markdown puede cambiar; formato desconocido produce SOURCE_INVALID. No se asegura stock, no se resuelven sesiones de código postal y no se aplican combos o membresías. No hay cobertura general validada de categorías. Ver `docs/source-validation.md`.

Pruebas: `npm test`. Las respuestas capturadas son evidencia de regresión, no el catálogo actual ni el modo demo.

Documentación: https://docs.firecrawl.dev/api-reference/endpoint/search y https://docs.firecrawl.dev/api-reference/endpoint/scrape.
