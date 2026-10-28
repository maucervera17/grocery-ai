# Pruebas de catálogo y ubicación — 27 de octubre de 2026

Precios publicados observados en consultas reales; no representan confirmación de disponibilidad local. Las respuestas de la segunda ronda también se reprocesaron con el extractor final. No se usaron fixtures como respuestas live.

| Consulta | Tiendas con productos obtenidos | Ofertas | Alcance |
|---|---|---:|---|
| desodorante axe | Chedraui, Bodega Aurrera, Walmart | 3 | Comparación por contenido equivalente |
| leche entera | Chedraui, Bodega Aurrera, Walmart | 3 | Comparación por contenido equivalente |
| huevo | Bodega Aurrera, Walmart | 2 | Comparación por contenido equivalente |
| arroz blanco | Chedraui | 1 | Cobertura insuficiente para elegir tienda |
| pasta espagueti | Chedraui, Walmart | 4 | Comparación por contenido equivalente |
| detergente ariel | Bodega Aurrera, Walmart | 4 | Hay polvo/líquido: no declarar un ganador entre unidades distintas |

## Fallos encontrados y corregidos

- «Devolución no disponible» se confundía con falta de existencias.
- Una presentación alternativa agotada invalidaba el SKU seleccionado.
- Un descuento de Chedraui y su precio anterior en la misma línea no se reconocían.
- «Pasta espagueti» no coincidía con «Spaghetti»; plurales y «Axxe» no se normalizaban.
- Las consultas simultáneas excedían los límites de Firecrawl. Se espacian por endpoint y un 429 ya no se reintenta inmediatamente.
- Los resultados incluían utensilios y dispensadores para búsquedas de alimentos. Se excluyen candidatos incompatibles y se siguen validando las fichas principales.
- Una única tienda no permite declarar la tienda más barata.

## Prueba real por CP

- 06170: 0 ofertas con evidencia local. chedraui: LOCATION_REQUIRES_ADDRESS; bodega-aurrera: LOCATION_VERIFICATION_FAILED; walmart: LOCATION_VERIFICATION_FAILED.
- 09410: 0 ofertas con evidencia local. chedraui: LOCATION_REQUIRES_ADDRESS; bodega-aurrera: LOCATION_VERIFICATION_FAILED; walmart: LOCATION_VERIFICATION_FAILED.
- 03104: 0 ofertas con evidencia local. chedraui: LOCATION_REQUIRES_ADDRESS; bodega-aurrera: LOCATION_VERIFICATION_FAILED; walmart: LOCATION_VERIFICATION_FAILED.

Los tres CP siguen sin confirmación automatizada. Chedraui requiere un flujo de dirección aún no implementado; no se enviaron las direcciones completas proporcionadas. Walmart y Bodega Aurrera fallaron en la selección de zona. La UI distingue explícitamente consulta local y precios publicados; cambiar CP borra resultados previos y activa la comprobación local. No se promete disponibilidad con precios de otra zona.

## Validación final

54 pruebas automatizadas pasan, además de compilación TypeScript y sintaxis del cliente. Chrome probó la frase exacta «que tienda tiene el mejor precio en desodorantes Axxe» con Claude y Firecrawl reales: cinco productos, fotos y enlaces. La comparación distingue aerosoles en ml y barras en g. Cambios de ubicación 06170 → 09410 → 03104 comprobados en la interfaz, sin conservar resultados previos. Esto valida el manejo de ubicación; no convierte los fallos de los proveedores en confirmaciones de disponibilidad.
